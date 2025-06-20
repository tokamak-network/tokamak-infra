terraform {
  required_version = ">= 1.5.5"
}

provider "aws" {
  profile = var.profile
  region  = var.region
}

module "vpc" {
  source = "./modules/aws/vpc"

  azs          = var.azs
  vpc_cidr     = var.vpc_cidr
  vpc_name     = var.vpc_name
  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/aws/eks"

  region             = var.region
  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  eks_cluster_admins = var.eks_cluster_admins
}

module "efs" {
  source = "./modules/aws/efs"

  efs_name           = var.efs_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "acm" {
  source = "./modules/aws/acm"

  parent_domain = var.parent_domain
  service_names = var.service_names
}

module "secretsmanager" {
  source = "./modules/aws/secretsmanager"

  cluster_name = var.cluster_name
}

module "k8s" {
  source = "./modules/k8s"

  network_name                       = var.network_name
  profile                            = var.profile
  region                             = var.region
  vpc                                = module.vpc
  cluster_name                       = module.eks.cluster_name
  fargate_profiles                   = module.eks.fargate_profiles
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  cluster_oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn                  = module.eks.oidc_provider_arn
  aws_acm_certificate_validation     = module.acm.aws_acm_certificate_validation
  aws_secretsmanager_id              = module.secretsmanager.aws_secretsmanager_id
  external_secret_namespace          = var.external_secret_namespace
  es_endpoint                        = module.ec2_instance.es_endpoint
}

module "waf" {
  source = "./modules/aws/waf"

  cluster_name = module.eks.cluster_name
}

module "s3_alb" {
  source = "./modules/aws/s3"

  bucket_name = var.alb_bucket_name
}

module "lambda" {
  source = "./modules/aws/lambda"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  source_version = var.lambda_source_version
  function_name  = var.lambda_function_name
  s3_bucket_id   = module.s3_alb.bucket_id
  s3_bucket_arn  = module.s3_alb.bucket_arn
  es_endpoint    = module.ec2_instance.es_endpoint
  es_port        = module.ec2_instance.es_port
  es_basic_auth  = module.ec2_instance.es_basic_auth
  git_user_name  = var.git_user_name
  git_repo_name  = var.git_repo_name
  network_name   = var.network_name
}

module "rds" {
  source = "./modules/aws/rds"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  rds_name = "${var.cluster_name}-rds"
}

module "ec2_instance" {
  source = "./modules/aws/ec2"

  network_name = var.network_name

  ami           = var.ec2_ami
  instance_type = var.ec2_instance

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  parent_domain = var.parent_domain
}
