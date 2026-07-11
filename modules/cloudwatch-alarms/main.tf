# CPU utilization alarm (ASG-level)
# This alarm monitors the average CPU utilization across all instances in the ASG
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeded 80% for 10 minutes"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  tags = {
    Name        = "${var.project_name}-cpu-alarm"
    Environment = var.project_name
  }
}

# Note: Memory and disk alarms require instance-level metrics from CloudWatch Agent.
# Since ASG instances are dynamic, these alarms should be created manually after
# instances launch, or use a Lambda function to create them dynamically.
# The CloudWatch Agent is configured to publish these metrics to the CWAgent namespace.
#
# To create memory/disk alarms manually:
# 1. Go to CloudWatch Console → Alarms → Create Alarm
# 2. Select metric: CWAgent → InstanceId → mem_used_percent or disk_used_percent
# 3. Set threshold and notification action (SNS topic)
