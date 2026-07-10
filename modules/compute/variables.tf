variable "name" {
  description = "Name prefix for resources"
  type        = string
}
variable "ami_id" {
  description = "AMI ID for instances"
  type        = string
}
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}
variable "ec2_security_group_id" {
  description = "Security group attached to EC2 instances"
  type        = string
}
variable "rds_secret_arn" {
  description = "ARN of the RDS Secrets Manager secret"
  type        = string
}
variable "ecr_repository_url" {
  description = "URL of the ECR repository"
  type        = string
}
variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
}
variable "image_tag" {
  description = "Docker image tag to pull from ECR"
  type        = string
}
variable "rds_endpoint" {
  description = "RDS database endpoint"
  type        = string
}
variable "rds_port" {
  description = "RDS database port"
  type        = number
}
variable "rds_db_name" {
  description = "RDS database name"
  type        = string
}
variable "rds_db_user" {
  description = "RDS database username"
  type        = string
}