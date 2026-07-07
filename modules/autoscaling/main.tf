resource "aws_autoscaling_group" "this" {
    name = "${var.name}-asg"

    desired_capacity     = var.desired_capacity
    min_size             = var.min_size
    max_size             = var.max_size

    vpc_zone_identifier  = var.public_subnet_ids

    launch_template {
        id      = var.launch_template_id
        version = var.launch_template_version
    }

    health_check_type         = "ELB"
    health_check_grace_period = 300
    
    force_delete = true

    tag {
        key                 = "Name"
        value               = var.name
        propagate_at_launch = true
    }
    target_group_arns = var.target_group_arns

    termination_policies = [
        "OldestInstance"
    ]
}