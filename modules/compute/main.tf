resource "aws_key_pair" "this" {

  key_name   = var.key_name
  public_key = file(var.public_key_path)

  tags = {
    Name = "${var.name}-key"
  }
}

resource "aws_launch_template" "this" {

  name = "${var.name}-launch-template"

  image_id = var.ami_id
  instance_type = var.instance_type


  vpc_security_group_ids = [
    var.ec2_security_group_id
  ]


  key_name = aws_key_pair.this.key_name

  user_data = base64encode(
    file("${path.module}/user_data.sh")
  )

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted = true
      delete_on_termination = true

    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
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