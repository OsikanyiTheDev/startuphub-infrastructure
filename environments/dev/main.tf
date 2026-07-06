module "networking" {
  source = "../../modules/networking"

  project_name = "startuphub-dev"

  vpc_cidr = var.vpc_cidr

  public_subnet_1_cidr = var.public_subnet_1_cidr
  public_subnet_2_cidr = var.public_subnet_2_cidr

  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
}
module "security" {
  source = "../../modules/security"

  name   = "startuphub-dev"
  vpc_id = module.networking.vpc_id


  ssh_cidr  = var.ssh_cidr
  http_cidr = var.http_cidr
}

module "compute" {
  source = "../../modules/compute"

  name              = "startuphub-dev"
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  subnet_id         = module.networking.public_subnet_1_id
  security_group_id = module.security.security_group_id
  key_name          = "startuphub-dev-key"
  public_key_path   = "../../keys/startuphub-dev-key.pub"
}
