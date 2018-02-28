resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags {
    Name = "prod-${var.app_name}"
  }
}

output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}
