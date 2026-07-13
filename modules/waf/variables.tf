variable "alb_arn" {
  description = "ARN of the Application Load Balancer to protect"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "rate_limit" {
  description = "Maximum requests per 5 minutes per IP address"
  type        = number
  default     = 2000
}

variable "enable_sql_injection_protection" {
  description = "Enable AWS Managed SQL Injection rules"
  type        = bool
  default     = true
}

variable "enable_xss_protection" {
  description = "Enable AWS Managed Cross-Site Scripting (XSS) rules"
  type        = bool
  default     = true
}

variable "enable_ip_reputation" {
  description = "Enable AWS Managed IP Reputation rules"
  type        = bool
  default     = true
}
