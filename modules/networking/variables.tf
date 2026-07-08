variable "project_name" {
  description = "Project name used for naming AWS resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

############################
# Public Subnets
############################

variable "public_subnet_1_cidr" {
  description = "CIDR block for Public Subnet 1"
  type        = string
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for Public Subnet 2"
  type        = string
}

############################
# Private Application Subnets
############################

variable "private_subnet_1_cidr" {
  description = "CIDR block for Private Application Subnet 1"
  type        = string
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for Private Application Subnet 2"
  type        = string
}

############################
# Private Database Subnets
############################

variable "private_db_subnet_1_cidr" {
  description = "CIDR block for Private Database Subnet 1"
  type        = string
}

variable "private_db_subnet_2_cidr" {
  description = "CIDR block for Private Database Subnet 2"
  type        = string
}