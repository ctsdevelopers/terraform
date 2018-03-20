data "terraform_remote_state" "vpc" {
  backend = "local"

  config {
    path = "vpc/terraform.tfstate"
  }
}

data "terraform_remote_state" "route53" {
  backend = "local"

  config {
    path = "../route53/terraform.tfstate"
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
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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


  # access from ssh jump box && webserver
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ssh-jumpbox-sg.id}", "${aws_security_group.web-server.id}"]
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
    lb_port           = 443
    lb_protocol       = "https"
    ssl_certificate_id = "${data.terraform_remote_state.route53.cert_arn}"
  }

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
    target              = "HTTP:80/ping"
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
    engine_version       = "5.7.21"
    instance_class       = "db.t2.micro"
    name                 = "${var.db_name}"
    username             = "${var.app_name}"
    password             = "${var.db_pass}"
    port                 = 3306
    vpc_security_group_ids = ["${aws_security_group.my-db-private.id}"] 
    db_subnet_group_name = "${aws_db_subnet_group.mysql.name}"
    #storage_encrypted    = true
    final_snapshot_identifier = "snapshot"
    backup_retention_period = 2
    backup_window       = "04:00-04:30"
    maintenance_window  = "Sun:06:00-Sun:09:00"

    tags {
      Name = "kinetix"
    }
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
sudo apt install awscli -y
sudo mkdir /root/.ssh/
sudo ssh-keyscan -H bitbucket.org >> /root/.ssh/known_hosts

while [ ! -f /root/.ssh/id_rsa ]; do
  sudo aws s3 cp s3://chroma-bitbucket-key/id_rsa /root/.ssh/id_rsa --region us-east-2
  sleep 2
done

sudo chmod 400 /root/.ssh/id_rsa

#sudo echo -e "[agent]\nip-10-0-11-246.us-east-2.compute.internal" >> /etc/puppetlabs/puppet/puppet.conf
sudo sed -i "2i10.0.11.246 ip-10-0-11-246.us-east-2.compute.internal" /etc/hosts
sudo puppet agent --test --server ip-10-0-11-246.us-east-2.compute.internal 

cd /home/ubuntu/
sudo git clone -b development git@bitbucket.org:cmeintegrations/kinetix-lis.git 

sudo mkdir /var/www/kinetix-lis
sudo mv /home/ubuntu/kinetix-lis/* /var/www/kinetix-lis/
sudo aws s3 cp s3://chroma-bitbucket-key/.env-kinetix-lis /var/www/kinetix-lis/.env --region us-east-2
sudo chown -R ubuntu:www-data /var/www

sudo rm -rf /home/ubuntu/kinetix-lis
sudo apt install zip unzip php7.1-zip -y
cd /var/www/kinetix-lis
sudo find /var/www/kinetix-lis -type f -exec chmod 664 {} \;    
sudo find /var/www/kinetix-lis -type d -exec chmod 775 {} \;
sudo chgrp -R www-data storage bootstrap/cache
sudo chmod -R ug+rwx storage bootstrap/cache
sudo composer install
sudo apt-get install libgtk2.0-0 libgdk-pixbuf2.0-0 libfontconfig1 libxrender1 libx11-6 libglib2.0-0  libxft2 libfreetype6 libc6 zlib1g libpng12-0 libstdc++6-4.8-dbg-arm64-cross libgcc1 -y
sudo apt install libssl-dev=1.0.2g-1ubuntu4.10 -y
sudo apt-mark hold libssl-dev
sudo chown -R ubuntu:www-data vendor/
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
  desired_capacity          = 1
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
