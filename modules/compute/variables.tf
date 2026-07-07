variable "name" {
  description = "Name prefix for resources"
  type = string
}


variable "ami_id" {
  description = "AMI ID for instances"
  type = string
}


variable "instance_type" {
  description = "EC2 instance type"
  type = string
}



variable "ec2_security_group_id" {
  description = "Security group attached to EC2 instances"
  type = string
}



variable "key_name" {
  description = "AWS key pair name"
  type = string
}



variable "public_key_path" {
  description = "Path to public SSH key"
  type = string
}