variable "name" {
  description = "Name prefix for the ALB"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security Group for the ALB"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
}