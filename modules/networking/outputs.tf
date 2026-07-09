output "vpc_id" {
  value = aws_vpc.this.id
}

#################################
# Public Subnets
#################################

output "public_subnet_1_id" {
  value = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  value = aws_subnet.public_2.id
}

#################################
# Private Application Subnets
#################################

output "private_subnet_1_id" {
  value = aws_subnet.private_1.id
}

output "private_subnet_2_id" {
  value = aws_subnet.private_2.id
}

#################################
# Private Database Subnets
#################################

output "private_db_subnet_1_id" {
  description = "Private database subnet 1"
  value       = aws_subnet.private_db_1.id
}

output "private_db_subnet_2_id" {
  description = "Private database subnet 2"
  value       = aws_subnet.private_db_2.id
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs"
  value = [
    aws_subnet.private_db_1.id,
    aws_subnet.private_db_2.id
  ]
}

#################################
# Networking Components
#################################

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.this.id
}

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private Route Table ID"
  value       = aws_route_table.private.id
}
