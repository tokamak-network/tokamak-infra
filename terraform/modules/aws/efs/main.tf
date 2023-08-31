data "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_ids)

  id = var.private_subnet_ids[count.index]
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

module "efs" {
  source = "terraform-aws-modules/efs/aws"

  # File system
  name           = var.efs_name
  creation_token = "${var.efs_name}-token"
  encrypted      = true
  attach_policy  = false

  throughput_mode = "elastic"

  lifecycle_policy = {
    transition_to_ia = "AFTER_30_DAYS"
  }

  # Backup policy
  enable_backup_policy = true
}

resource "aws_security_group" "this" {
  name        = var.efs_name
  description = "EFS security group"

  revoke_rules_on_delete = true
  vpc_id                 = var.vpc_id
}

resource "aws_security_group_rule" "this" {
  security_group_id = aws_security_group.this.id

  description = "NFS ingress from VPC private subnets"
  type        = "ingress"
  from_port   = "2049"
  to_port     = "2049"
  protocol    = "tcp"
  cidr_blocks = [data.aws_vpc.vpc.cidr_block]
}

resource "aws_efs_mount_target" "this" {
  count = length(data.aws_subnet.private_subnets)

  file_system_id  = module.efs.id
  security_groups = [aws_security_group.this.id]
  subnet_id       = data.aws_subnet.private_subnets[count.index].id
}
