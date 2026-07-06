variable "name" {
  description = "Name prefix for the EC2 instance"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "The instance type for the EC2 instance"
  type        = string
}

variable "subnet_id" {
    description = "Public subnet ID"
    type       = string
}

variable "security_group_id" {
    description = "Security group ID"
    type       = string
}

variable "key_name" {
    description = "Key pair name for SSH access"
    type        = string
}

variable "public_key_path" {
    description = "Path to the public key file for the key pair"
    type        = string
}