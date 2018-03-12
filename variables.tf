variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-east-2"
}

variable "app_name" {
  description = "The name of the lab receiving the LIS"
  default = "kinetix"
}

variable "db_name" {
  description = "The db name of the lab receiving the LIS"
  default = "kinetix_master"
}

variable "db_pass" {
  description = "The password for the RDS instance"
  default = "CG7FmwG905oVpJ3sVpc"
}

############
#kinetic.pub
############
variable "public_key" {
  description = "Public key to be attached to the server"
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUhptE5/5KwGJA+01RG3XwGpBKVQ/vl8mmFMwfJqaR7WRy7Ro5VEvTfo8JEEVc8PNYukqSwI8ogivVlR0n/RUmatmGLTn3FaP8t1sm21C3OnJdXxz6oM+CBJYso1ovK44XRWgfqdwuBfPjggFY2gWf7tOhkj9HTXtL0i99YNzWXWeQNaWuxpYgbdH02xCCEArSoslKnpWfDjJ+G8C4Mj7ugIfQA1aQS0ALd73SPnPjmkvmjgWZWEEdiie9arsv3rvgv02+uOJwmU/i3y3387BJKmBNJj5O6Tacs181AnPmYvihWZznJHa6KezUelUxtioT7t0+Prp6LgZFJ5qa4Igx AzureAD+JoeDelNano@MSI"
}
