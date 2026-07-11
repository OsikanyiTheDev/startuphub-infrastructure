resource "aws_launch_template" "this" {

  name = "${var.name}-launch-template"

  image_id      = var.ami_id
  instance_type = var.instance_type


  vpc_security_group_ids = [
    var.ec2_security_group_id
  ]

  user_data = base64encode(
    templatefile("${path.module}/user_data.tpl", {
      project_name       = var.project_name
      ecr_repository_url = var.ecr_repository_url
      aws_region         = var.aws_region
      image_tag          = var.image_tag
      rds_endpoint       = var.rds_endpoint
      rds_port           = var.rds_port
      rds_db_name        = var.rds_db_name
      rds_db_user        = var.rds_db_user
      rds_secret_arn     = var.rds_secret_arn
    })
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true

    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  update_default_version = true
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.name
    }
  }
  tags = {
    Name = "${var.name}-launch-template"
  }
}