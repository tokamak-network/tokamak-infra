profile                   = "mainnet" # you must change it in your local file ~/.aws/config
region                    = "ap-northeast-2"
azs                       = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
network_name              = "mainnet"
cluster_name              = "titan"
cluster_version           = "1.30"
vpc_cidr                  = "192.168.0.0/16"
vpc_name                  = "titan/VPC"
efs_name                  = "titan"
parent_domain             = "titan.tokamak.network"
service_names             = ["*"]
alb_bucket_name           = "s3-alb-access-logs-lambda-titan"
lambda_function_name      = "alb_logs_to_elasticsearch_titan"
git_user_name             = "tokamak-network"
git_repo_name             = "ALB_S3_Logs_To_ES"
lambda_source_version     = "2.0"
external_secret_namespace = "titan"
eks_cluster_admins = [
  "arn:aws:iam::211125399844:user/theo@tokamak.network",
]
ec2_ami      = "ami-0c031a79ffb01a803"
ec2_instance = "t3.medium"
