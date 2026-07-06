variable "name" {
  description = "The name of the security group."
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the security group will be created."
  type        = string
}

variable "ssh_cidr" {
  description = "The CIDR block for SSH access."
  type        = list(string)
}

variable "http_cidr" {
  description = "The CIDR block for HTTP access."
  type        = list(string)
}