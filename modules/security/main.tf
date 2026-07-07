#################################
# ALB security Group
#################################

resource "aws_security_group" "alb" {
    name = "${var.name}-alb-sg"
    description = "Secuirty Group for the ALB"
    vpc_id = var.vpc_id

    # HTTP access (environment controlled)
    ingress {
        description = "HTTP"

        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = var.http_cidr
    }

    # HTTP acess (environment controlled)
    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = var.https_cidr
    }

    egress {
        description = "All outbound traffic"
        from_port = 0
        to_port = 0
        protocol = "-1"
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
    name       = "${var.name}-ec2-sg"
    description = "Security group for ${var.name}"
    vpc_id     = var.vpc_id


    #SSH access restricted 
    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = var.ssh_cidr
    }


    #HTTP access ( from ALB)
    ingress {
        description = "HTTP from ALB"
        from_port   = 80
        to_port     = 80
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

