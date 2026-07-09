resource "aws_iam_policy" "rds_secret_access" {

  name = "${var.project_name}-rds-secret-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = module.rds.master_user_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_secret_access" {
  role       = module.compute.ec2_role_name
  policy_arn = aws_iam_policy.rds_secret_access.arn
}