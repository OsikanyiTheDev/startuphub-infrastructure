output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_id" {
  value = module.networking.public_subnet_id
}

output "igw_id" {
  value = module.networking.igw_id
}

output "public_route_table_id" {
  value = module.networking.public_route_table_id
}