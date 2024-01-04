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
}

module "efs" {
  source = "./modules/aws/efs"

  efs_name           = var.efs_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "efs_es" {
  source = "./modules/aws/efs"

  efs_name           = "${var.efs_name}_es"
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
  efs_id                             = module.efs.efs_id
  efs_es_id                          = module.efs_es.efs_id
  aws_secretsmanager_id              = module.secretsmanager.aws_secretsmanager_id
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

  source_version = var.lambda_source_version
  function_name  = var.lambda_function_name
  s3_bucket_id   = module.s3_alb.bucket_id
  s3_bucket_arn  = module.s3_alb.bucket_arn
  es_endpoint    = var.es_endpoint
  es_basic_auth  = var.es_basic_auth
  git_user_name  = var.git_user_name
  git_repo_name  = var.git_repo_name
}