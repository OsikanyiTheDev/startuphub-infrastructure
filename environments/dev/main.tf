module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name

  vpc_cidr = var.vpc_cidr

  public_subnet_1_cidr = var.public_subnet_1_cidr
  public_subnet_2_cidr = var.public_subnet_2_cidr

  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr

  private_db_subnet_1_cidr = var.private_db_subnet_1_cidr
  private_db_subnet_2_cidr = var.private_db_subnet_2_cidr
}

module "security" {
  source = "../../modules/security"

  name   = var.project_name
  vpc_id = module.networking.vpc_id


  alb_http_cidr  = var.alb_http_cidr
  alb_https_cidr = var.alb_https_cidr
}

module "compute" {
  source = "../../modules/compute"

  name         = var.project_name
  project_name = var.project_name

  ami_id        = var.ami_id
  instance_type = var.instance_type

  ec2_security_group_id = module.security.ec2_security_group_id
  rds_secret_arn        = module.rds.master_user_secret_arn

  ecr_repository_url = module.ecr.repository_url
  aws_region         = var.region
  image_tag          = var.ecr_image_tag
  rds_endpoint       = module.rds.address
  rds_port           = module.rds.port
  rds_db_name        = module.rds.database_name
  rds_db_user        = var.db_username
}

module "alb" {
  source = "../../modules/alb"

  name = var.project_name

  vpc_id = module.networking.vpc_id
  public_subnet_ids = [
    module.networking.public_subnet_1_id,
    module.networking.public_subnet_2_id
  ]
  enable_deletion_protection = var.enable_deletion_protection

  alb_security_group_id = module.security.alb_security_group_id
}



module "autoscaling" {

  source = "../../modules/autoscaling"

  name = var.project_name

  launch_template_id      = module.compute.launch_template_id
  launch_template_version = module.compute.launch_template_latest_version

  private_subnet_ids = [
    module.networking.private_subnet_1_id,
    module.networking.private_subnet_2_id
  ]

  target_group_arns = [
    module.alb.target_group_arn
  ]

  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size

  depends_on = [
    module.alb
  ]

  force_delete = var.force_delete

}

module "rds" {
  source = "../../modules/rds"

  name = var.project_name

  subnet_ids = [
    module.networking.private_db_subnet_1_id,
    module.networking.private_db_subnet_2_id
  ]

  security_group_ids = [
    module.security.rds_security_group_id
  ]

  engine = var.db_engine

  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage

  database_name = var.db_name
  username      = var.db_username

  multi_az = var.db_multi_az

  publicly_accessible = var.db_publicly_accessible
  deletion_protection = var.db_deletion_protection
}

module "ecr" {
  source = "../../modules/ecr"

  project_name         = var.project_name
  image_tag_mutability = var.ecr_image_tag_mutability
  scan_on_push         = var.ecr_scan_on_push
}

module "iam" {
  source = "../../modules/iam"

  project_name      = var.project_name
  github_repository = var.github_repository
  aws_region        = var.region
}

module "cloudwatch_logs" {
  source = "../../modules/cloudwatch-logs"

  project_name = var.project_name
}

module "sns" {
  source = "../../modules/sns"

  project_name = var.project_name
  alert_email  = var.alert_email
}

module "cloudwatch_alarms" {
  source = "../../modules/cloudwatch-alarms"

  project_name           = var.project_name
  sns_topic_arn          = module.sns.sns_topic_arn
  autoscaling_group_name = module.autoscaling.autoscaling_group_name
}

module "cloudwatch_dashboard" {
  source = "../../modules/cloudwatch-dashboard"

  project_name            = var.project_name
  aws_region              = var.region
  autoscaling_group_name  = module.autoscaling.autoscaling_group_name
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  rds_instance_identifier = module.rds.instance_identifier
}
#testing for ci/cd final for cloudwatch
