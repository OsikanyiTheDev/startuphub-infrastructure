output "endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "RDS database address"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS database port"
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}
output "master_user_secret_arn" {
  description = "ARN of the RDS master user secret"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}