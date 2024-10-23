profile                   = "testnet" # you must change it in your local file ~/.aws/config
region                    = "ap-northeast-2"
azs                       = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
network_name              = "thanos-holesky"
cluster_name              = "thanos-holesky"
cluster_version           = "1.30"
vpc_cidr                  = "192.168.0.0/16"
vpc_name                  = "thanos-holesky/VPC"
efs_name                  = "thanos-holesky"
parent_domain             = "thanos-holesky.tokamak.network"
service_names             = ["*"]
alb_bucket_name           = "s3-alb-access-logs-lambda-thanos-holesky"
lambda_function_name      = "alb_logs_to_elasticsearch_thanos-holesky"
git_user_name             = "tokamak-network"
git_repo_name             = "ALB_S3_Logs_To_ES"
lambda_source_version     = "1.0"
external_secret_namespace = "thanos"
eks_cluster_admins = [
  "arn:aws:iam::992382494724:user/austin.o@onther.io",
  "arn:aws:iam::992382494724:user/steven@tokamak.network",
  "arn:aws:iam::992382494724:user/shane.k@onther.io",
]
ec2_ami      = "ami-0c031a79ffb01a803"
ec2_instance = "t3.medium"
