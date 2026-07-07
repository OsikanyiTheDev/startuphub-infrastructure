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

output "alb_dbs_name" {
  value = module.alb.alb_dns_name
}

output "lanuch_template_id" {
  value = module.compute.launch_template_id
}

output "autoscaling_group_name" {
  value = module.autoscaling.autoscaling_group_name
}