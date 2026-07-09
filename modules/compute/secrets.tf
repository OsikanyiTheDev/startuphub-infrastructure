############################################
# Allow EC2 to read RDS generated secret
############################################
resource "aws_iam_policy" "rds_secret_access" {
  name = "${var.name}-rds-secret-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.rds_secret_arn
      }
    ]
  })
}


############################################
# Attach policy to EC2 role
############################################
resource "aws_iam_role_policy_attachment" "rds_secret_access" {
  role = aws_iam_role.ec2_ssm.name
  policy_arn = aws_iam_policy.rds_secret_access.arn
}