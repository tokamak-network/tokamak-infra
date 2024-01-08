data "aws_vpc" "vpc" {
  id = var.vpc_id
}

resource "aws_db_subnet_group" "default" {
  name       = var.rds_name
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "this" {
  name        = "${var.rds_name}_for_rds"
  description = "RDS security group"

  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  ingress {
    description = "ingress from VPC private subnets"
    from_port   = var.from_port
    to_port     = var.to_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.rds_name}-parameter-group"
  family = "postgres14"

  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }
}

resource "aws_db_instance" "default" {
  identifier             = var.rds_name
  allocated_storage      = var.rds_allocated_storage
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t3.micro"
  username               = "postgres"
  password               = "postgres"
  db_subnet_group_name   = aws_db_subnet_group.default.name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  skip_final_snapshot    = true
}
