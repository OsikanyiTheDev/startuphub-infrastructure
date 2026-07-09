output "alb_security_group_id" {
  value = aws_security_group.alb.id
  description = "The ID of alb security group"
}

output "ec2_security_group_id" {
  value       = aws_security_group.ec2.id
  description = "The ID of the ec2 security group"
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
  description = "The ID of RDS security group"
}
