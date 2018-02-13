variable "public_key_path" {
  description = "Enter the path to the SSH Public Key to add to AWS."
  default = "~/.ssh/kinetix.pem.pub"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-east-2"
}

variable "lab_name" {
  description = "The name of the lab receiving the LIS"
  default = "kinetix"
}
