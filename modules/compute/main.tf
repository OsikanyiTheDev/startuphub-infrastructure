resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  tags = {
    Name = var.key_name
  }
}
resource "aws_launch_template" "this" {
    name_prefix   = "${var.name}-"

    image_id          = var.ami_id
    instance_type = var.instance_type

    vpc_security_group_ids = [var.ec2_security_group_id]

    key_name      = aws_key_pair.this.key_name

    update_default_version = true


    user_data = base64encode(file("${path.module}/user_data.sh"))

    block_device_mappings {
        device_name = "/dev/sda1"
        ebs {
            volume_size = 20
            volume_type = "gp3"
            delete_on_termination = true
            encrypted = true
        }
    }

    monitoring {
        enabled = true
    }

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