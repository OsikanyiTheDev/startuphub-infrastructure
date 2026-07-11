variable "name" {
  description = "Name prefic for RDS resources"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet for IDs for DB subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to RDS"
  type        = list(string)
}

variable "engine" {
  description = "Database engine"
  type        = string
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Storage size in GB"
  type        = number
}

variable "database_name" {
  description = "Initial database name"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "multi_az" {
  description = "Enable Multi AZ deployment"
  type        = bool
}

variable "publicly_accessible" {
  description = "Whether RDS should have public access"
  type        = bool
}

variable "deletion_protection" {
  description = "Protect database from deletion"
  type        = bool
}