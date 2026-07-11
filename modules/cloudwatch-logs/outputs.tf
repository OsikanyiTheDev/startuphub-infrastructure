output "ec2_system_log_group" {
  description = "Name of the EC2 system log group"
  value       = aws_cloudwatch_log_group.ec2_system.name
}

output "docker_log_group" {
  description = "Name of the Docker log group"
  value       = aws_cloudwatch_log_group.docker.name
}

output "application_log_group" {
  description = "Name of the application log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "user_data_log_group" {
  description = "Name of the user-data log group"
  value       = aws_cloudwatch_log_group.user_data.name
}
