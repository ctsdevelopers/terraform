resource "aws_subnet" "public_1" {
  vpc_id     = "${aws_vpc.vpc.id}"
  availability_zone = "us-east-2a"
  cidr_block = "10.0.0.0/22"
  map_public_ip_on_launch = true

  tags {
    Name = "public-subnet-1"
  }
}

output "public_1_subnet_id" {
    value = "${aws_subnet.public_1.id}"
}

resource "aws_subnet" "public_2" {
  vpc_id     = "${aws_vpc.vpc.id}"
  availability_zone = "us-east-2b"
  cidr_block = "10.0.4.0/22"
  map_public_ip_on_launch = true

  tags {
    Name = "public-subnet-2"
  }
}

output "public_2_subnet_id" {
    value = "${aws_subnet.public_2.id}"
}

resource "aws_subnet" "ephemeral_1" {
  vpc_id     = "${aws_vpc.vpc.id}"
  availability_zone = "us-east-2a"
  cidr_block = "10.0.8.0/22"
  map_public_ip_on_launch = false

  tags {
    Name = "ephemeral-subnet-1"
  }
}

resource "aws_subnet" "ephemeral_2" {
  vpc_id     = "${aws_vpc.vpc.id}"
  availability_zone = "us-east-2b"
  cidr_block = "10.0.12.0/22"
  map_public_ip_on_launch = false

  tags {
    Name = "ephemeral-subnet-2"
  }
}

output "private_1_subnet_id" {
  value = "${aws_subnet.ephemeral_1.id}"
}

output "subnets" {
    value = ["${aws_subnet.ephemeral_1.id}", "${aws_subnet.ephemeral_2.id}"]
}
