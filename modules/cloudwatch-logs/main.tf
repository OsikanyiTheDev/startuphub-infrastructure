resource "aws_cloudwatch_log_group" "ec2_system" {
  name              = "/aws/ec2/${var.project_name}/system"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-ec2-system-logs"
    Environment = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "docker" {
  name              = "/aws/ec2/${var.project_name}/docker"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-docker-logs"
    Environment = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/ec2/${var.project_name}/application"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-application-logs"
    Environment = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "user_data" {
  name              = "/aws/ec2/${var.project_name}/user-data"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-user-data-logs"
    Environment = var.project_name
  }
}
