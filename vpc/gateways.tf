resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "prod-${var.app_name}-igw"
  }
}

resource "aws_eip" "nat_gw_eip" {
  vpc = true
  # TODO: Make this a variable.
  associate_with_private_ip = "10.0.8.1"
}

resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.nat_gw_eip.id}"
  subnet_id     = "${aws_subnet.public_1.id}"
}
