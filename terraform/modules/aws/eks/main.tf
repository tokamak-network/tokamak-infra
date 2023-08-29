module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_private_access = false
  cluster_endpoint_public_access  = true

  vpc_id     = var.vpc_id
  subnet_ids = setunion(var.private_subnet_ids, var.public_subnet_ids)

  fargate_profiles = {
    default = {
      name       = "default"
      subnet_ids = var.private_subnet_ids
      selectors = [
        {
          namespace = "*"
        }
      ]
    }
  }
}
