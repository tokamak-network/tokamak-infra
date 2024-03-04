profile                   = "dev" # you must change it in your local file ~/.aws/config
region                    = "ap-northeast-2"
azs                       = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
network_name              = "thanos-sepolia-test"
cluster_name              = "thanos-sepolia-test"
cluster_version           = 1.28
vpc_cidr                  = "192.168.0.0/16"
vpc_name                  = "thanos-sepolia-test/VPC"
efs_name                  = "thanos-sepolia-test"
parent_domain             = "thanos-sepolia-test.tokamak.network"
service_names             = ["*"]
alb_bucket_name           = "s3-alb-access-logs-lambda-thanos-sepolia-test"
lambda_function_name      = "alb_logs_to_elasticsearch_thanos-sepolia-test"
es_endpoint               = ""
es_basic_auth             = ""
git_user_name             = "tokamak-network"
git_repo_name             = "ALB_S3_Logs_To_ES"
lambda_source_version     = "1.0"
external_secret_namespace = "thanos"
kms_key_administrators = [
  "arn:aws:iam::156512274928:user/steven.l@onther.io",
  "arn:aws:iam::156512274928:user/austin.o@onther.io"
]
