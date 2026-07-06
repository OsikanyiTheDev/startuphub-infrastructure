module "networking" {
    source = "../../modules/networking"

    project_name = "startuphub-dev"

    vpc_cidr              = var.vpc_cidr

    public_subnet_1_cidr  = var.public_subnet_1_cidr
    public_subnet_2_cidr  = var.public_subnet_2_cidr

    private_subnet_1_cidr = var.private_subnet_1_cidr
    private_subnet_2_cidr = var.private_subnet_2_cidr
}
module "security" {
    source = "../../modules/security"

    name     = "startuphub-dev"
    vpc_id   = module.networking.vpc_id


    ssh_cidr = var.ssh_cidr
    http_cidr = var.http_cidr
}

module "ec2" {
  source = "../../modules/ec2"

  name              = "startuphub-dev"
  ami_id            = "ami-0d28727121d5d4a3c" # Ubuntu 22.04/24.x depending region
  subnet_id         = module.networking.public_subnet_1_id
  security_group_id = module.security.security_group_id
  key_name          = var.key_name
}