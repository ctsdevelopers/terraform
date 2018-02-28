resource "aws_key_pair" "auth" {
  key_name   = "${var.app_name}"
  public_key = "${var.public_key}"
}
