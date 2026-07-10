#################################
# ALB security Group
#################################

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Secuirty Group for the ALB"
  vpc_id      = var.vpc_id

  # HTTP access (environment controlled)
  ingress {
    description = "HTTP"

    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_http_cidr
  }

  # HTTP acess (environment controlled)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_https_cidr
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-alb-sg"
  }
}

#######################################
#EC2 Security Group
#######################################
resource "aws_security_group" "ec2" {
  name        = "${var.name}-ec2-sg"
  description = "Allows application traffic from ALB only"
  vpc_id      = var.vpc_id


  #HTTP access ( from ALB)
  ingress {
    description = "HTTP from ALB"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [
      aws_security_group.alb.id
    ]
  }

  #outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-ec2-sg"
  }
}



resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "Allos PostgreSQL acess only from the EC2 instances"

  vpc_id = var.vpc_id

  ################################
  # PostgreSQL from EC2 only
  ################################
  ingress {
    description = "PostgreSQL from EC2"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      aws_security_group.ec2.id
    ]
  }

  ################################
  # Outbound
  ################################
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "${var.name}-rds-sg"
  }


}