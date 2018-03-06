data "terraform_remote_state" "vpc" {
  backend = "local"

  config {
    path = "vpc/terraform.tfstate"
  }
}

resource "aws_db_subnet_group" "mysql" {
  name       = "main"
  subnet_ids = ["${data.terraform_remote_state.vpc.subnets}"]

  tags {
    Name = "MySQL DB subnet group"
  }
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb-sg" {
  name        = "elb-sg"
  description = "Security group for public facing ELBs"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # HTTPS access from anywhere
#  ingress {
#    from_port   = 443
#    to_port     = 80
#    protocol    = "tcp"
#    cidr_blocks = ["0.0.0.0/0"]
#  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access the instances over SSH and HTTP
resource "aws_security_group" "web-server" {
  name        = "web-server-sg"
  description = "Security group for servers"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  # SSH access from ssh jump box
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ssh-jumpbox-sg.id}"]
  }

  # HTTP access from the elb inside VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = ["${aws_security_group.elb-sg.id}"]
  }
  

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our security group to access the RDS instances over SSH and port 3306 
resource "aws_security_group" "my-db-private" {
  name        = "my_db_sec_group_private"
  description = "Security group for backend servers and private ELBs"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ssh-jumpbox-sg.id}"]
  }

  # access from ssh jump box
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ssh-jumpbox-sg.id}"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#
# Load Balancers. Uses the instance module outputs.
#

# Public Backend ELB
resource "aws_elb" "web" {
  name = "elb-public-web"

  subnets = ["${data.terraform_remote_state.vpc.public_1_subnet_id}", "${data.terraform_remote_state.vpc.public_2_subnet_id}"]
  security_groups = ["${aws_security_group.elb-sg.id}"]

  cross_zone_load_balancing = true
  idle_timeout = 60
  connection_draining = true
  connection_draining_timeout = 400

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 30
  }
}


###########################################################################
########################INSTANCES##########################################
###########################################################################

data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"] # Canonical
}

data "aws_ami" "puppet_ami" {
  most_recent = true
  name_regex = "^ebs-chroma-bastion"
}

resource "aws_db_instance" "db_mysql" {
    allocated_storage    = 10
    engine               = "mysql"
    instance_class       = "db.t2.micro"
    name                 = "${var.app_name}"
    username             = "${var.app_name}"
    password             = "H#59VJYcC9rvD$"
    port                 = 3306
    vpc_security_group_ids = ["${aws_security_group.my-db-private.id}"] 
    db_subnet_group_name = "${aws_db_subnet_group.mysql.name}"
#    storage_encrypted    = true
#    final_snapshot_identifier = "snapshot"
}

resource "aws_launch_configuration" "as_conf" {
  image_id      = "${data.aws_ami.puppet_ami.image_id}"
  key_name      = "${aws_key_pair.auth.key_name}"
  name_prefix   = "kinetix-server-"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.web-server.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.chroma_profile.id}"
user_data = <<EOF
#!/bin/bash
sudo apt-get update -y
sudo apt install nginx -y
sudo apt install awscli -y
sudo mkdir /root/.ssh/
sudo ssh-keyscan -H bitbucket.org >> /root/.ssh/known_hosts

while [ ! -f /root/.ssh/id_rsa ]; do
  sudo aws s3 cp s3://chroma-bitbucket-key/id_rsa /root/.ssh/id_rsa --region us-east-2
  sleep 2
done

sudo chmod 400 /root/.ssh/id_rsa

sudo echo -e "[agent]\nip-10-0-11-246.us-east-2.compute.internal" >> /etc/puppetlabs/puppet/puppet.conf
sudo sed -i "2i10.0.11.246 ip-10-0-11-246.us-east-2.compute.internal" /etc/hosts
sudo puppet agent --test --server ip-10-0-11-246.us-east-2.compute.internal 

cd /home/ubuntu/
sudo git clone git@bitbucket.org:cmeintegrations/kinetix-lis.git 

sudo mkdir /var/www/kinetix-lis
sudo mv /home/ubuntu/kinetix-lis/* /var/www/kinetix-lis/
sudo chown -R ubuntu:www-data /var/www
sudo rm -rf /home/ubuntu/kinetix-lis

sudo aws s3 cp s3://chroma-bitbucket-key/.env /var/www/kinetix-lis/ --region us-east-2
EOF
  lifecycle {
    create_before_destroy = true
    ignore_changes = ["name"]
  }
}

resource "aws_autoscaling_group" "asg" {
  availability_zones        = "${var.zones}"
  name                      = "${var.app_name}-web-asg"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.as_conf.name}"
  load_balancers            = ["${aws_elb.web.name}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.subnets}"]

  lifecycle {
    create_before_destroy = true
    ignore_changes = ["name"]
  }
}

variable "zones" {
  default = ["us-east-2a", "us-east-2b", "us-east-2c"]
}
