profile                   = "dev" # you must change it in your local file ~/.aws/config
region                    = "ap-northeast-2"
azs                       = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
network_name              = "prepare-titan-test"
cluster_name              = "prepare-titan-test"
cluster_version           = 1.28
vpc_cidr                  = "192.168.0.0/16"
vpc_name                  = "prepare-titan-test/VPC"
efs_name                  = "prepare-titan-test"
parent_domain             = "prepare-titan-test.tokamak.network"
service_names             = ["*"]
alb_bucket_name           = "s3-alb-access-logs-lambda-prepare-titan-test"
lambda_function_name      = "alb_logs_to_elasticsearch_prepare-titan-test"
es_endpoint               = ""
es_basic_auth             = ""
git_user_name             = "tokamak-network"
git_repo_name             = "ALB_S3_Logs_To_ES"
lambda_source_version     = "1.0"
external_secret_namespace = "default"
kms_key_administrators = [
  "arn:aws:iam::156512274928:user/austin.o@onther.io"
]

# TODO : make cluster -> make manifest?
#        ROUTE 53 Terraform?
