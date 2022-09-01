# Tokamak Network for AWS Fargate
This is the `kustomize overlays` files for AWS Fargate. The k8s resourses are based on `../../bases` files.

## Prerequisite

### Tools
- `kubectl` [Install](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux)
- `aws` [Install](https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/getting-started-install.html)
- `eksctl` [Install](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/eksctl.html)

Create the config file for aws cli in the `$HOME/.aws/config` following the [documentation](https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/cli-configure-files.html). You just need to set `region`, `aws_access_key_id`, `aws_secret_access_key`.

### AWS EKS cluster
`EKS cluster` is required. (You must have at least one `private subnet` and at least one `public subnet` within your VPC for Fargate.)
- Follow the [documentation](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/create-cluster.html).

`Fargate Profile` are required. (`kube-system`, `default`, `cert-manager` namespaces.)
- Follow the [documentation](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/fargate.html).

Update kubeconfig
```
aws eks update-kubeconfig --region {us-east-1} --name {tokamak-test} # your region-code and cluster name
```

Update core-dns for using fargate
```
kubectl patch deployment coredns \
    -n kube-system \
    --type json \
    -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
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

# you have to execute this command for each fargate subnet
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

Some setting in your subnet is required. See the [documentation](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html) for details.
```
Private subnets – Must be tagged in the following format. This is so that Kubernetes and the AWS Load Balancer Controller know that the subnets can be used for internal load balancers. If you use eksctl or an Amazon EKS AWS AWS CloudFormation template to create your VPC after March 26, 2020, then the subnets are tagged appropriately when they're created. For more information about the Amazon EKS AWS AWS CloudFormation VPC templates, see Creating a VPC for your Amazon EKS cluster.

Key – kubernetes.io/role/internal-elb
Value – 1

Public subnets – Must be tagged in the following format. This is so that Kubernetes knows to use only those subnets for external load balancers instead of choosing a public subnet in each Availability Zone (based on the lexicographical order of the subnet IDs). If you use eksctl or an Amazon EKS AWS CloudFormation template to create your VPC after March 26, 2020, then the subnets are tagged appropriately when they're created. For more information about the Amazon EKS AWS CloudFormation VPC templates, see Creating a VPC for your Amazon EKS cluster.

Key – kubernetes.io/role/elb
Value – 1
```

## Environment
You have to create `secret.env` file
```
cd ./kustomize/envs/rinkeby
cp secret.env.example secret.env

# set your private keys
```

## Run
```
# working directory

kubectl apply -k ./kustomize/bases/aws
EFS_VOLUME_ID={your EFS FileSystemId} envsubst < ./kustomize/overlays/aws_rinkeby/pv.yaml | kubectl apply -f -
kubectl apply -k ./kustomize/overlays/aws_rinkeby
```

If you see this error, run again `kubectl apply -k ./kustomize/bases/aws`.
```
Error from server (InternalError): error when creating "STDIN": Internal error occurred: failed calling webhook "webhook.cert-manager.io": failed to call webhook: Post "https://cert-manager-webhook.cert-manager.svc:443/mutate?timeout=10s": no endpoints available for service "cert-manager-webhook"
```
This is an error according to the resource creation order. We will fix this error.

## Delete
```
kubectl delete -k ./kustomize/overlays/aws_rinkeby
EFS_VOLUME_ID={your EFS FileSystemId} envsubst < ./kustomize/overlays/aws_rinkeby/pv.yaml | kubectl delete -f -
kubectl delete -k ./kustomize/bases/aws
```