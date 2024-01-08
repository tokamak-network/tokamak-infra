module "rds" {
  source = "./postgres"

  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids

  rds_name = var.rds_name

  rds_allocated_storage = 10

  from_port = 5432
  to_port   = 5432

  db_parameters = [
    {
      name         = "log_connections"
      value        = "1"
      apply_method = "pending-reboot"
    }
  ]
}
