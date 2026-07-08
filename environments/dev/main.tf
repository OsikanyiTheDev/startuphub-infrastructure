module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name

  vpc_cidr = var.vpc_cidr

  public_subnet_1_cidr = var.public_subnet_1_cidr
  public_subnet_2_cidr = var.public_subnet_2_cidr

  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
}
module "security" {
  source = "../../modules/security"

  name   = var.project_name
  vpc_id = module.networking.vpc_id


  ssh_cidr       = var.ssh_cidr
  alb_http_cidr  = var.alb_http_cidr
  alb_https_cidr = var.alb_https_cidr
}

module "compute" {
  source = "../../modules/compute"

  name = var.project_name

  ami_id        = var.ami_id
  instance_type = var.instance_type

  ec2_security_group_id = module.security.ec2_security_group_id

  key_name        = var.key_name
  public_key_path = "../../keys/${var.key_name}.pub"
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