variable "github_repository" {
  description = "GitHub repository name (format: owner/repo)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}