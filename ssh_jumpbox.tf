resource "aws_security_group" "ssh-jumpbox-sg" {
  name        = "ssh-jumpbox-sg"
  description = "Allows for ssh-ing into vpc"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0 
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ssh_jumpbox" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.auth.key_name}"
  vpc_security_group_ids = ["${aws_security_group.ssh-jumpbox-sg.id}"]
  associate_public_ip_address = true
  # See the documentation https://www.terraform.io/docs/configuration/interpolation.html
  subnet_id = "${data.terraform_remote_state.vpc.public_1_subnet_id}"

  tags {
    Name = "ssh-jumpbox"
  }
}
