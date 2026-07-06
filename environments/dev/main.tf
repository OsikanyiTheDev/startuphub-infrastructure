module "networking" {
    source = "../../modules/networking"

    project_name       = "startuphub-dev"
    vpc_cidr           = "10.0.0.0/16"
    public_subnet_cidr = "10.0.1.0/24"
}

module "security" {
    source = "../../modules/security"

    name     = "startuphub-dev"
    vpc_id   = module.networking.vpc_id


    ssh_cidr = var.ssh_cidr
    http_cidr = var.http_cidr
}