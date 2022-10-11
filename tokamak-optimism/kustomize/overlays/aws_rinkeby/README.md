# Tokamak Network for AWS Fargate
This is the `kustomize overlays` files for AWS Fargate. The k8s resourses are based on `../../bases` files.

## Prerequisite
You have to run this commands in same terminal session

### Tools
- `kubectl` [Install](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux)
- `aws` [Install](https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/getting-started-install.html)
- `eksctl` [Install](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/eksctl.html)
- `helm` [Install](https://helm.sh/docs/intro/install)

Create the config file for aws cli in the `$HOME/.aws/config` following the [documentation](https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/cli-configure-files.html). You only need to set `region`, `aws_access_key_id`, `aws_secret_access_key`.

### AWS EKS cluster
Create cluster
```
eksctl create cluster --name {my-cluster} --region {region-code} --fargate

# cluster name, region-code
```

Create an IAM OIDC Provider for eksctl iamserviceaccount
```
eksctl utils associate-iam-oidc-provider --cluster {my-cluster} --region {region-code} --approve

# cluster name, region-code
```

### AWS EFS
Create an IAM Poilicy to be used by EFS_CSI_Driver
```
curl -o iam-policy-example.json https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json

aws iam create-policy \
    --policy-name {AmazonEKS_EFS_CSI_Driver_Policy} \
    --policy-document file://iam-policy-example.json

rm iam-policy-example.json

# policy name you want
```

Create an IAM Role and deploy Kubernetes ServiceAccount
```
eksctl create iamserviceaccount \
    --cluster {my-cluster} \
    --namespace kube-system \
    --name efs-csi-controller-sa \
    --role-name "{AmazonEKS_EFS_CSI_Driver_Role}" \
    --attach-policy-arn arn:aws:iam::{111122223333}:policy/{AmazonEKS_EFS_CSI_Driver_Policy} \
    --approve \
    --region {region-code}

# cluster name, role name you want, user id, policy name set in the command above, region-code
```

Create an EFS filesystem for EKS
```
vpc_id=$(aws eks describe-cluster \
    --name {my-cluster} \
    --region {region-code} \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

cidr_range=$(aws ec2 describe-vpcs \
    --vpc-ids $vpc_id \
    --region {region-code} \
    --query "Vpcs[].CidrBlock" \
    --output text)

security_group_id=$(aws ec2 create-security-group \
    --group-name {MyEfsSecurityGroup} \
    --description "My EFS security group" \
    --vpc-id $vpc_id \
    --region {region-code} \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $security_group_id \
    --region {region-code} \
    --protocol tcp \
    --port 2049 \
    --cidr $cidr_range

file_system_id=$(aws efs create-file-system \
    --region {region-code} \
    --performance-mode generalPurpose \
    --query 'FileSystemId' \
    --output text)

# you can get the subnet-id being used by fargate following coammand
aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpc_id --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' --region {region-code} --output text

# you have to execute this command for each private subnet being used by fargate.
aws efs create-mount-target \
    --file-system-id $file_system_id \
    --region {region-code} \
    --subnet-id {subnet-EXAMPLEe2ba886490} \
    --security-groups $security_group_id

# cluster name, security group name you want, region-code, subnet id
```

### AWS Application Load Balancer
Create an IAM Policy for Load Balancer Controller
```
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.3/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name {AWSLoadBalancerControllerIAMPolicy} \
    --policy-document file://iam_policy.json

rm iam_policy.json

# poily name you want
```

Create an IAM Role and deploy Kubernetes ServiceAccount
```
eksctl create iamserviceaccount \
  --cluster={my-cluster} \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "{AmazonEKSLoadBalancerControllerRole}" \
  --attach-policy-arn=arn:aws:iam::{111122223333}:policy/{AWSLoadBalancerControllerIAMPolicy} \
  --region {region-code} \
  --approve

# cluster name, role name you want, user id, policy name set in the command above, region-code
```

Install `aws-load-balancer-controller` by helm
```
helm repo add eks https://aws.github.io/eks-charts

helm repo update

helm install \
  aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName={my-cluster} \
  --set region={region-code} \
  --set vpcId=$vpc_id \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# cluster name, region-code
```

## Amazon Managed Service for Prometheus (Options)
Create new Amazon Managed Service for Prometheus
```
aws amp create-workspace --alias {workspace name} --region {region-code}

# workspace name you want, region-code you want
# remember your workspace id from output
```

Add fargate profile for prometheus
```
eksctl create fargateprofile \
    --cluster {my-cluster} \
    --region {region-code} \
    --name prometheus \
    --namespace prometheus

# cluster name, region-code
```

Create an IAM Role and deploy Kubernetes ServiceAccount for Amazon Managed Service for Prometheus
```
eksctl create iamserviceaccount \
  --cluster={my-cluster} \
  --namespace=prometheus \
  --name=amp-iamproxy-ingest-service-account \
  --role-name "amp-iamproxy-ingest-role" \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess \
  --region {region-code} \
  --approve

# cluster name, region-code
```

Install `prometheus` by helm
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

helm install amp-prometheus-chart prometheus-community/prometheus -n prometheus \
--set serviceAccounts.server.create=false \
--set serviceAccounts.server.name=amp-iamproxy-ingest-service-account \
--set server.remoteWrite[0].url="https://aps-workspaces.{region-code}.amazonaws.com/workspaces/{amp workspace id}/api/v1/remote_write" \
--set server.remoteWrite[0].sigv4.region={region-code} \
--set server.remoteWrite[0].queue_config.max_samples_per_send=1000 \
--set server.remoteWrite[0].queue_config.max_shards=200 \
--set server.remoteWrite[0].queue_config.capacity=2500 \
--set server.persistentVolume.enabled=false \
--set alertmanager.enabled=false \
--set nodeExporter.enabled=false \
--set pushgateway.enabled=false

# region-code, amp workspace id
```

## Environment
### Deploy contracts
You have to deploy contracts in the l1. use the `Onther-Tech/tokamak-optimism-v2`.

### Env file
You have to copy `.env` file from `.env.example` and modify it.

**.env**
```
AWS_EKS_CLUSTER_NAME={your cluster name}
AWS_VPC_ID={your cluster vpc id}
AWS_REGION={region-code}
EFS_VOLUME_ID={efs file system id}
CERTIFICATE_ARN={certificate arn for https}
```

You have to set some `*.env` files in `./kustomize/envs/rinkeby`
```
# you have to set 'URL' to your contract address file's url in the 'batch-submitter.env', 'common.env', 'data-transport-layer.env', 'relayer.env'
# you have to set 'ROLLUP_STATE_DUMP_PATH' to your state dump file's url in the 'l2geth.env'
```

You have to create and set `secret.env` file
```
cd ./kustomize/envs/rinkeby
cp secret.env.example secret.env

# set your private keys in secret.env
```

## Run
```
# in root directory

./tokamak-optimism.sh create aws_rinkeby
```

## Delete
Delete k8s resources
```
# in root directory

helm uninstall aws-load-balancer-controller -n kube-system

./tokamak-optimism.sh delete aws_rinkeby
```

Delete cluster and aws resources
```
eksctl delete iamserviceaccount --cluster={my-cluster} --namespace=kube-system --name=aws-load-balancer-controller --region {region-code}

eksctl delete iamserviceaccount --cluster={my-cluster} --namespace=kube-system --name=efs-csi-controller-sa --region {region-code}

# all efs mount targets must be removed before removing the file system.
# you can get mount target id following command
aws efs describe-mount-targets --file-system-id $file_system_id --region {region-code} --query MountTargets[].MountTargetId --output text

# delete mount-target. you have to execute this command for each mount target.
aws efs delete-mount-target --mount-target-id {mount target id} --region {region-code}

# delete security group used by efs file system
aws ec2 delete-security-group --group-id $security_group_id --region {region-code}

# delete file system
aws efs delete-file-system --file-system-id $file_system_id --region {region-code}

# delete cluster
eksctl delete cluster --name {my-cluster} --region {region-code}

cluster name, region-code, mount target id
# if you lose terminal session when deleting cluster, you need to find some values such as $file_system_id, $security_group_id ​​through the aws console or aws cli.
```