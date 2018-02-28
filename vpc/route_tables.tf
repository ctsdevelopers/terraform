# Public route tables
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = "${aws_subnet.public_1.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = "${aws_subnet.public_2.id}"
  route_table_id = "${aws_route_table.public.id}"
}

# Private route tables
resource "aws_route_table" "ephemeral" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "ephemeral_1" {
  subnet_id      = "${aws_subnet.ephemeral_1.id}"
  route_table_id = "${aws_route_table.ephemeral.id}"
}

resource "aws_route_table_association" "ephemeral_2" {
  subnet_id      = "${aws_subnet.ephemeral_2.id}"
  route_table_id = "${aws_route_table.ephemeral.id}"
}
