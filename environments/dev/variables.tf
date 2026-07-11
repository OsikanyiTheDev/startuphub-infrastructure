variable "project_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

############################
# Public Subnets
############################

variable "public_subnet_1_cidr" {
  type = string
}

variable "public_subnet_2_cidr" {
  type = string
}

############################
# Private Application Subnets
############################

variable "private_subnet_1_cidr" {
  type = string
}

variable "private_subnet_2_cidr" {
  type = string
}

############################
# Private Database Subnets
############################

variable "private_db_subnet_1_cidr" {
  type = string
}

variable "private_db_subnet_2_cidr" {
  type = string
}

variable "alb_http_cidr" {
  type = list(string)
}

variable "alb_https_cidr" {
  type = list(string)
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
  description = "minimum size of the autoscaling group"
}

variable "max_size" {
  type        = number
  description = "maximum size of the autoscaling group"
}

variable "enable_deletion_protection" {
  description = "enable ALB deletion protection"
  type        = bool
}

variable "force_delete" {
  type = bool
}

variable "db_engine" {
  type = string
}
variable "db_engine_version" {
  type = string
}
variable "db_instance_class" {
  type = string
}
variable "db_allocated_storage" {
  type = number
}
variable "db_name" {
  type = string
}
variable "db_username" {
  type = string
}

variable "db_multi_az" {
  type = bool
}
variable "db_publicly_accessible" {
  type = bool
}
variable "db_deletion_protection" {
  type = bool
}

############################
# ECR
############################

variable "ecr_image_tag_mutability" {
  type = string
}

variable "ecr_scan_on_push" {
  type = bool
}

variable "ecr_image_tag" {
  type = string
}

############################
#git hub repo
############################
variable "github_repository" {
  description = "GitHub repository in owner/repo format (e.g., OsikanyiTheDev/startuphub-infrastructure)"
  type        = string
}

###########################
#sns 
############################
variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}
