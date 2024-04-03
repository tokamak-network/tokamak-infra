profile                   = "dev" # you must change it in your local file ~/.aws/config
region                    = "ap-northeast-2"
azs                       = ["ap-northeast-2a" ,"ap-northeast-2b"]
network_name              = "dev"
cluster_name              = "dev"
cluster_version           = 1.28
vpc_cidr                  = "192.168.0.0/16"
vpc_name                  = "dev/VPC"
efs_name                  = "dev"
parent_domain             = "dev.tokamak.network"
service_names             = ["*"]
alb_bucket_name           = "s3-alb-access-logs-lambda-dev"
lambda_function_name      = "alb_logs_to_elasticsearch_dev"
es_endpoint               = ""
es_basic_auth             = ""
git_user_name             = "tokamak-network"
git_repo_name             = "ALB_S3_Logs_To_ES"
lambda_source_version     = "1.0"
external_secret_namespace = "dev"
kms_key_administrators = [
  "arn:aws:iam::156512274928:user/steven.l@onther.io",
  "arn:aws:iam::156512274928:user/austin.o@onther.io",
  "arn:aws:iam::156512274928:user/steven@tokamak.network",
]
