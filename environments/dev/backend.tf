terraform {
  backend "s3" {
    bucket = "osikanyithedev-terraform-state-2026"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}
