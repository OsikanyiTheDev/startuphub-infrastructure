resource "aws_security_group" "this" {
    name       = "${var.name}-sg"
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


    #HTTP access (environment controlled)
    ingress {
        description = "HTTP"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = var.http_cidr
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
        Name = "${var.name}-sg"
    }
}

