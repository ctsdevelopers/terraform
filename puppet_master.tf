resource "aws_security_group" "puppet-master-sg" {
  name        = "puppet-master-sg"
  description = "Security group for puppet master"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ssh-jumpbox-sg.id}"]
  }

  ingress {
    from_port   = 8140
    to_port     = 8140
    protocol    = "tcp"
    security_groups = ["${aws_security_group.web-server.id}"]
  }

  egress {
    from_port       = 0 
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "puppet-master" {
  ami           = "${data.aws_ami.puppet_ami.image_id}"
  instance_type = "t2.small"
  key_name      = "${aws_key_pair.auth.key_name}"
  vpc_security_group_ids = ["${aws_security_group.puppet-master-sg.id}"]
  # See the documentation https://www.terraform.io/docs/configuration/interpolation.html
  subnet_id = "${data.terraform_remote_state.vpc.private_1_subnet_id}"

  tags {
    Name = "puppet-master"
  }
}
