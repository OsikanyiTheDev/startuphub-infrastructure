variable "vpc_cidr" {
  type = string
}

variable "public_subnet_1_cidr" {
  type = string
}

variable "public_subnet_2_cidr" {
  type = string
}

variable "private_subnet_1_cidr" {
  type = string
}

variable "private_subnet_2_cidr" {
  type = string
}

variable "ssh_cidr" {
  type = list(string)
}

variable "http_cidr" {
  type = list(string)
}

variable "key_name" {
  type = string
  description = "SSH key pair name"
}