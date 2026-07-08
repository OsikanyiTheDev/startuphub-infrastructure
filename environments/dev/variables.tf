variable "project_name" {
  type = string
}
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

variable "alb_http_cidr" {
  type = list(string)
}

variable "alb_https_cidr" {
  type = list(string)
}

variable "key_name" {
  type        = string
  description = "SSH key pair name"
}

variable "ami_id" {
  type        = string
  description = "The AMI ID to use for the EC2 instance"
}

variable "instance_type" {
  type        = string
  description = "The instance type for the EC2 instance"
}

variable "desired_capacity" {
  type        = number
  description = "Desired capacity of the autoscaling group"
}

variable "min_size" {
  type        = number
  description = "Minimum size of the autoscaling group"
}

variable "max_size" {
  type        = number
  description = "Maximum size of the autoscaling group"
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
}

variable "force_delete" {
  type = bool
}