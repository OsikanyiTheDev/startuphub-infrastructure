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

output "instance_id" {
  value = module.ec2.instance_id
}

output "public_ip" {
  value = module.ec2.public_ip
}

output "public_dns" {
  value = module.ec2.public_dns
}