variable "name" {
    description = "Name prefix for the autoscaling group"
    type        = string
}

variable "launch_template_id" {
    description = "ID of the launch template"
    type        = string
}

variable "launch_template_version" {
    description = "launch template Version"
    type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the Auto Scaling Group"
  type        = list(string)
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

variable "target_group_arns" {
    description = "target group of the arn"
    type = list(string)
}

variable "force_delete" {
  type = bool
}