output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_1_id" {
  value = module.networking.public_subnet_1_id
}

output "public_subnet_2_id" {
  value = module.networking.public_subnet_2_id
}

output "private_subnet_1_id" {
  value = module.networking.private_subnet_1_id
}

output "private_subnet_2_id" {
  value = module.networking.private_subnet_2_id
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "launch_template_id" {
  value = module.compute.launch_template_id
}

output "autoscaling_group_name" {
  value = module.autoscaling.autoscaling_group_name
}

output "target_group_arn" {
  description = "ARN of the ALB Target Group"
  value       = module.alb.target_group_arn
}

output "rds_secret_arn" {
  value = module.rds.master_user_secret_arn
}