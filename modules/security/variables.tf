variable "name" {
  description = "The name of the security group."
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the security group will be created."
  type        = string
}

variable "alb_http_cidr" {
  description = "The CIDR block for HTTP access."
  type        = list(string)
}

variable "alb_https_cidr" {
  description = "The CIDR block for HTTPS access."
  type        = list(string)
}