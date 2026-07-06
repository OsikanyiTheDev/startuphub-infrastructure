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
  type        = string
  description = "SSH key pair name"
}

variable "ami_id" {
  type        = string
  description = "The AMI ID to use for the EC2 instance"
  default     = "ami-0d28727121d5d4a3c" # Ubuntu 22.04/24.x depending region
  }

variable "instance_type" {
  type        = string
  description = "The instance type for the EC2 instance"
  default     = "t3.micro"
}