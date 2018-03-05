resource "aws_iam_instance_profile" "chroma_profile" {
  name = "chroma-profile"
  role = "${aws_iam_role.chroma_role.name}"
}

resource "aws_iam_role" "chroma_role" {
  name = "chroma-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":[{
    "Effect":"Allow",
    "Principal":{
      "Service":"ec2.amazonaws.com"
    },
    "Action":"sts:AssumeRole"
  }]
}
EOF
}
