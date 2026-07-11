resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.subnet_ids
  tags = {
    Name = "${var.name}-db-subnet-group"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-postgres"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage           = var.allocated_storage
  db_name                     = var.database_name
  username                    = var.username
  manage_master_user_password = true

  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = var.security_group_ids
  publicly_accessible     = var.publicly_accessible
  multi_az                = var.multi_az
  storage_type            = "gp3"
  storage_encrypted       = true
  backup_retention_period = 0
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  deletion_protection = var.deletion_protection
  skip_final_snapshot = true

  tags = {
    Name = "${var.name}-postgres"
  }
}