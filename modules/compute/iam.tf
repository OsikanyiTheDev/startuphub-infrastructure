############################################
# EC2 IAM Role for Systems Manager Access
############################################

resource "aws_iam_role" "ec2_ssm" {

  name = "${var.name}-ec2-ssm-role"
  assume_role_policy = jsonencode({

    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.name}-ec2-ssm-role"
  }
}


############################################
# Attach SSM Managed Policy
############################################

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

############################################
# Attach ECR Read-Only Policy
############################################

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


############################################
# EC2 Instance Profile
############################################

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-ec2-instance-profile"
  role = aws_iam_role.ec2_ssm.name

}