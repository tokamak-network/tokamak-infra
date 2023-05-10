# Kubernetes

Resources for running the tokamak network based on kubernetes

## Directory Strcture

```
kustomize
├─ bases: kubernetes bases resource like statefulset, deployment, service, etc
├─ envs: env files and kustomize file to make kubernetes configmap
├─ overlays: overlays set entire kubernetes resource and it can override other resources
└─ scripts: scripts and kustomize file to make kubernetes configmap
```

## on Minikube

### Prerequisites

- `kubectl` **Minimum version v1.20** [Install notes](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux)
- `minikube` from a [minikube page](https://minikube.sigs.k8s.io/docs/start/)
- Docker

### Configuration

There are resources in `kustomize/envs`, `kustomize/overlays/local` for each environment.

Local is for local network test. It consists of one `l1`, one `l2`, one `data-transport-layer`, one `deployer`, one `batch-submitter` and one `relayer`.

You must create `secret.env` from `secret.env.example` in `kustomize/envs/local`..

### Run

This is an example of `local`.

#### create a cluster

```
minikube start --cpus 4 --memory 16384
# customize the cps and the memory for your system
```

#### deploy local resource

```
./tokamak-optimism.sh create local/hardhat

minikube tunnel # (keep terminal session)
```

#### monitoring

```
kubectl get pods
```

If you can see all `Running` in the status, then everyting was successful!

This may take some time.(about 5m)

#### endpoint

Minikube doesn't provide port forwarding. this network is up,

```
l1 endpoint: http://{svc external address}:9545
l2 endpoint: http://{svc external address}:8545, ws://{svc external address}:8546
dtl endpoint: http://{svc external address}:7878
```

You can get `svc external address` to follow below command.

```
kubectl get svc

# NAME              TYPE           CLUSTER-IP      **EXTERNAL-IP**     PORT(S)          AGE
# hello-minikube1   LoadBalancer   10.96.184.178   **10.96.184.178**   8080:30791/TCP   40s
```

Notice that minkube is accessible from only local system.

### Delete cluster

```
minikube delete
```

## on AWS EKS

This is the `kustomize overlays` files for AWS Fargate. The k8s resourses are based on `../../bases` files.

### Prerequisite

You have to run this commands in same terminal session

- `kubectl` [Install](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux)
- `aws` [Install](https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/getting-started-install.html)
- `eksctl` [Install](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/eksctl.html)
- `helm` [Install](https://helm.sh/docs/intro/install)

Create the config file for aws cli in the `$HOME/.aws/config` following the [documentation](https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/cli-configure-files.html).

### Setup Kubernetes Cluster on AWS EKS

#### Set environment variables

Set `Cluster Name` and `Region Code`, `Account ID` on AWS to variables.
`Cluster Name` can be made you want.

```
cluster_name=<Cluster Name>
region=<Region Code>
account_id=<Account ID>
```

example:

```
cluster_name=tokamak-optimism-cluster
region=ap-northeast-2
account_id=$(aws sts get-caller-identity --query "Account" --output text)
```

#### Create KMS Customer managed key

Create KMS Key

```
kms_keyid=$(aws kms create-key \
            --description ${cluster_name} \
            --query "KeyMetadata.KeyId" \
            --output text)
```

Cretae alias for the key

```
aws kms create-alias --alias-name alias/${cluster_name} --target-key-id ${kms_keyid}
```

#### AWS EKS cluster

Create eks cluster with fargate.

```
eksctl create cluster --name ${cluster_name} --region ${region} --version 1.23 --fargate

```

Enabl KMS encryption on crated eks cluster

```
$ eksctl utils enable-secrets-encryption --cluster=${cluster_name} --key-arn=arn:aws:kms:${region}:${account_id}:key/${kms_keyid} --region=${region}

```

Create an IAM OIDC Provider for eksctl iamserviceaccount

```
eksctl utils associate-iam-oidc-provider --cluster ${cluster_name} --region ${region} --approve
```

Add fargate profile for prometheus-stack

```
eksctl create fargateprofile \
    --cluster ${cluster_name} \
    --region ${region} \
    --name monitoring \
    --namespace monitoring
```

#### Test cluster

check current context

```
kubectl config current-context
```

you can add the cluster to kubeconfig.

```
aws eks update-kubeconfig --region ${region} --name ${cluster_name}
```

#### AWS EFS

Create an IAM Poilicy named `AmazonEKS_EFS_CSI_Driver_Policy` to be used by EFS_CSI_Driver.

`AmazonEKS_EFS_CSI_Driver_Policy` can be changed you want. If the policy is already created, this step can be passed.

```
curl -o iam-policy-example.json https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json

aws iam create-policy \
    --policy-name AmazonEKS_EFS_CSI_Driver_Policy \
    --policy-document file://iam-policy-example.json

rm iam-policy-example.json
```

Create an IAM Role named `AmazonEKS_EFS_CSI_Driver_Role` and deploy Kubernetes ServiceAccount with the policy already created as `AmazonEKS_EFS_CSI_Driver_Policy`

`AmazonEKS_EFS_CSI_Driver_Role` can be changed you want.

```
eksctl create iamserviceaccount \
    --cluster ${cluster_name} \
    --namespace kube-system \
    --name efs-csi-controller-sa \
    --role-name "AmazonEKS_EFS_CSI_Driver_Role" \
    --attach-policy-arn arn:aws:iam::${account_id}:policy/AmazonEKS_EFS_CSI_Driver_Policy \
    --approve \
    --region ${region}
```

Create an EFS filesystem for EKS

```
vpc_id=$(aws eks describe-cluster \
    --name ${cluster_name} \
    --region ${region} \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

cidr_range=$(aws ec2 describe-vpcs \
    --vpc-ids $vpc_id \
    --region ${region} \
    --query "Vpcs[].CidrBlock" \
    --output text)

security_group_id=$(aws ec2 create-security-group \
    --group-name ${cluster_name}-sg \
    --description "${cluster_name} security group" \
    --vpc-id ${vpc_id} \
    --region ${region} \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id ${security_group_id} \
    --region ${region} \
    --protocol tcp \
    --port 2049 \
    --cidr ${cidr_range}

file_system_id=$(aws efs create-file-system \
    --region ${region} \
    --performance-mode generalPurpose \
    --query 'FileSystemId' \
    --output text)
```

Create an EFS filesystem for l2geth-replica

```
replica_file_system_id=$(aws efs create-file-system \
    --region ${region} \
    --performance-mode generalPurpose \
    --query 'FileSystemId' \
    --output text)
```

Get the private subnet id to for fargate

```
aws ec2 describe-subnets \
    --filters Name=vpc-id,Values=$vpc_id \
    --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' \
    --region ${region} \
    --output json
```

Create a mount-target for each subnet id. If there are 3 subnet ids, create 3 times.

Change `<my_subnet_id>` to the subnet id and execute next command each subnet id.

```
aws efs create-mount-target \
    --file-system-id ${file_system_id} \
    --region ${region} \
    --security-groups ${security_group_id} \
    --subnet-id <my_subnet_id>

aws efs create-mount-target \
    --file-system-id ${replica_file_system_id} \
    --region ${region} \
    --security-groups ${security_group_id} \
    --subnet-id <my_subnet_id>
```

#### AWS Application Load Balancer

Create an IAM Policy named `AWSLoadBalancerControllerIAMPolicy` for Load Balancer Controller

`AWSLoadBalancerControllerIAMPolicy` can be changed you want. If the policy is already created, this step can be passed.

```
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.3/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

rm iam_policy.json
```

Create an IAM Role named `AmazonEKSLoadBalancerControllerRole` and deploy Kubernetes ServiceAccount with the policy already created as `AWSLoadBalancerControllerIAMPolicy`

`AmazonEKSLoadBalancerControllerRole` can be changed you want.

```
eksctl create iamserviceaccount \
  --cluster=${cluster_name} \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerRole" \
  --attach-policy-arn=arn:aws:iam::${account_id}:policy/AWSLoadBalancerControllerIAMPolicy \
  --region ${region} \
  --approve
```

Install `aws-load-balancer-controller` by helm

```
helm repo add eks https://aws.github.io/eks-charts

helm repo update

helm install \
  aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${cluster_name} \
  --set region=${region} \
  --set vpcId=${vpc_id} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

#### Create IAM for logging

Create an IAM Policy named `eks-fargate-logging-policy` for Load Balancer Controller

```
curl -O https://raw.githubusercontent.com/aws-samples/amazon-eks-fluent-logging-examples/mainline/examples/fargate/cloudwatchlogs/permissions.json

aws iam create-policy --policy-name eks-fargate-logging-policy --policy-document file://permissions.json

rm -f permissions.json
```

Attach a policy to the automatically created eks role.

```
eks_rolearn=$(kubectl get configmaps/aws-auth -n kube-system -o=jsonpath='{.data.mapRoles}'|grep rolearn|cut -d ":" -f 2-|cut -d "/" -f 2|xargs)
account_id=$(aws sts get-caller-identity --query "Account" --output text)

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::${account_id}:policy/eks-fargate-logging-policy \
  --role-name ${eks_rolearn}
```
### Export cloudwatch logs to S3

1. Create Bucket is named `BUCKET_NAME`
2. Update the bucket permission

    Change `${REGION}`, `${BUCKET_NAME}` to own name.

    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "logs.${REGION}.amazonaws.com"
                },
                "Action": "s3:GetBucketAcl",
                "Resource": "arn:aws:s3:::${BUCKET_NAME}"
            },
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "logs.${REGION}.amazonaws.com"
                },
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
                "Condition": {
                    "StringEquals": {
                        "s3:x-amz-acl": "bucket-owner-full-control"
                    }
                }
            }
        ]
    }
    ```

3. Create IAM Policy is named `cloudwatch_export_task` for Lambda

    Change `${REGION}`, `${BUCKET_NAME}`, `${ACCOUNT_ID}` to own name.

    **cloudwatch_export_task** policy

    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": [
                    "logs:CreateExportTask",
                    "logs:Describe*",
                    "logs:ListTagsLogGroup"
                ],
                "Effect": "Allow",
                "Resource": "*"
            },
            {
                "Action": [
                    "ssm:DescribeParameters",
                    "ssm:GetParameter",
                    "ssm:GetParameters",
                    "ssm:GetParametersByPath",
                    "ssm:PutParameter"
                ],
                "Resource": "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter/log-exporter-last-export/*",
                "Effect": "Allow"
            },
            {
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                "Resource": "arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:/aws/lambda/log-exporter-*",
                "Effect": "Allow"
            },
            {
                "Sid": "AllowCrossAccountObjectAcc",
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:PutObjectACL"
                ],
                "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
            },
            {
                "Sid": "AllowCrossAccountBucketAcc",
                "Effect": "Allow",
                "Action": [
                    "s3:PutBucketAcl",
                    "s3:GetBucketAcl"
                ],
                "Resource": "arn:aws:s3:::${BUCKET_NAME}"
            }
        ]
    }
    ```

4. Create IAM Role is named `export_S3_for_lambda` included `cloudwatch_export_task` policy. and config timeout to `30s`
5. Create Lambda Function using `export_S3_for_lambda` Role.
6. Write follow code and deploy it.

    **log-exporter-to-s3** (python 3.10)

    ```
    import boto3
    import os
    from pprint import pprint
    import time

    logs = boto3.client('logs')
    ssm = boto3.client('ssm')

    def lambda_handler(event, context):
        extra_args = {}
        log_groups = []
        log_groups_to_export = []

        if 'S3_BUCKET' not in os.environ:
            print("Error: S3_BUCKET not defined")
            return

        print("--> S3_BUCKET=%s" % os.environ["S3_BUCKET"])

        while True:
            response = logs.describe_log_groups(**extra_args)
            log_groups = log_groups + response['logGroups']


            if not 'nextToken' in response:
                break
            extra_args['nextToken'] = response['nextToken']
        for log_group in log_groups:
            response = logs.list_tags_log_group(logGroupName=log_group['logGroupName'])
            log_group_tags = response['tags']
            if 'ExportToS3' in log_group_tags and log_group_tags['ExportToS3'] == 'true':
                log_groups_to_export.append(log_group['logGroupName'])

        for log_group_name in log_groups_to_export:
            tm = time.gmtime()
            export_to_time = int(round(time.time() * 1000))

            ssm_parameter_name = ("/log-exporter-last-export/%s" % log_group_name).replace("//", "/")
            try:
                ssm_response = ssm.get_parameter(Name=ssm_parameter_name)
                ssm_value = ssm_response['Parameter']['Value']
            except ssm.exceptions.ParameterNotFound:
                ssm_value = export_to_time - (24 * 60 * 60 * 1000)

            print("--> Exporting %s to %s" % (log_group_name, os.environ['S3_BUCKET']))
            if export_to_time - int(ssm_value) < (1 * 60 * 60 * 1000):
                # Haven't been 24hrs from the last export of this log group
                print("    Skipped until 24hrs from last export is completed")
                continue
            try:
                response = logs.create_export_task(
                    logGroupName=log_group_name,
                    fromTime=ssm_value,
                    to=export_to_time,
                    destination=os.environ['S3_BUCKET'],
                    destinationPrefix=time.strftime('%Y/%m/%d/%I/', tm) + log_group_name.strip("/")
                )
                print("    Task created: %s" % response['taskId'])
                time.sleep(3)
            except logs.exceptions.LimitExceededException:
                print("    Need to wait until all tasks are finished (LimitExceededException). Continuing later...")
                return
            except Exception as e:
                print("    Error exporting %s: %s" % (log_group_name, getattr(e, 'message', repr(e))))
                continue
            ssm_response = ssm.put_parameter(
                Name=ssm_parameter_name,
                Type="String",
                Value=str(export_to_time),
                Overwrite=True)
    ```

7. Add environments to lambda

    Change `${BUCKET_NAME}` to own name.

    ```
    S3_BUCKET=${BUCKET_NAME}
    ```

8. Add tags to store log groups in CloudWatch.

    ```
    ExportToS3: true
    ```

9. Add `EventBridge` Trigger is named `export-log-groups` with scheduled `cron(0 * * * ? *)`

10. Config lifecycle for s3 the bucket

* transitions Standard-IA after 30 days
* transitions Glacier Flexible Retrieval after 90 days


#### Create Secrets for AWS

Create fargate profile for External-Secrets.

```
eksctl create fargateprofile \
    --cluster ${cluster_name} \
    --name externalsecrets \
    --namespace external-secrets
```

Install External-Secrets using helm

```
helm repo add external-secrets https://charts.external-secrets.io

helm repo update

helm install external-secrets \
   external-secrets/external-secrets \
   -n external-secrets \
   --create-namespace \
   --set installCRDs=true \
   --set webhook.port=9443

kubectl get pods -n external-secrets
```

Generate Kay:Values on AWS Secret Manager.

* BATCH_SUBMITTER_SEQUENCER_PRIVATE_KEY
* BATCH_SUBMITTER_PROPOSER_PRIVATE_KEY
* MESSAGE_RELAYER__L1_WALLET

And copy `secret manager arn`

See [create_secret](https://docs.aws.amazon.com/ko_kr/secretsmanager/latest/userguide/create_secret.html)

Create a resource policy for the pod

```
# Fix it
secret_arn=arn:aws:secretsmanager:ap-northeast-2:005310045109:secret:tokamak-optimism-goerli/secrets-S9qW4n

# Fix it
policy_name=tokamak-optimism-goerli-nightly-deployment

POLICY_ARN=$(aws --region "${region}" --query Policy.Arn --output text iam create-policy --policy-name ${policy_name} --policy-document '{
    "Version": "2012-10-17",
    "Statement": [ {
        "Effect": "Allow",
        "Action": [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
        ],
        "Resource": "'${secret_arn}'"
    } ]
}')
```

Create the service account for eks

```
eksctl create iamserviceaccount \
  --name tokamak-optimism-deployment-sa \
  --region=${region} \
  --cluster ${cluster_name} \
  --attach-policy-arn ${POLICY_ARN} \
  --approve \
  --override-existing-serviceaccounts
```

### Environment

#### Deploy contracts

You have to deploy contracts in the l1. use the `Onther-Tech/tokamak-optimism-v2`.

#### Env file

You have to copy `.env` file from `.env.example` and modify it.

**.env**

```
AWS_EKS_CLUSTER_NAME={your cluster name}
AWS_VPC_ID={your cluster vpc id}
AWS_REGION={region-code}
EFS_VOLUME_ID={efs file system id}
CERTIFICATE_ARN={certificate arn for https}
```

You have to set some `*.env` files in `./kustomize/envs/goerli`

```
# you have to set 'URL' to your contract address file's url in the 'batch-submitter.env', 'common.env', 'data-transport-layer.env', 'relayer.env'
# you have to set 'ROLLUP_STATE_DUMP_PATH' to your state dump file's url in the 'l2geth.env'
```

You have to create and set `secret.env` file

```
cd ./kustomize/envs/goerli
cp secret.env.example secret.env

# set your private keys in secret.env
```

### Run

Use `tokamak-optimism.sh` script to run.

```
./tokamak-optimism.sh help
Usage:
  ./tokamak-optimism.sh [command]
    * commands
      - create
         - list
         - [cluster_name] [env_name]
      - delete
      - tag|tags ([resource])
      - update
         - config|list
         - all [tag_name]|undo
         - [resource] [tag_name]|undo
         - [resource] list
      - reload(restart)
         - list|all|[resource]

Examples:
 ./tokamak-optimism.sh create list
 ./tokamak-optimism.sh create hardhat-remote local
 ./tokamak-optimism.sh delete
 ./tokamak-optimism.sh tag
 ./tokamak-optimism.sh tag batch-submitter
 ./tokamak-optimism.sh update config
 ./tokamak-optimism.sh update list
 ./tokamak-optimism.sh update all release-1.0.1
 ./tokamak-optimism.sh update all undo
 ./tokamak-optimism.sh update batch-submitter release-1.0.1
 ./tokamak-optimism.sh update batch-submitter undo
 ./tokamak-optimism.sh update batch-submitter list
 ./tokamak-optimism.sh reload list
 ./tokamak-optimism.sh reload all
 ./tokamak-optimism.sh reload batch-submitter
```

create optimism to aws cluster(eks):

```
./tokamak-optimism.sh create goerli-nightly aws
```

create optimism to local cluster:

```
./tokamak-optimism.sh create goerli-nightly local
```

### Add IAM user

Edit `aws-auth` configmap to add new IAM user on AWS EKS

```
kubectl edit configmaps/aws-auth -n kube-system
```

Add `mapUsers` section.
Fill out `<Account_ID>` and `<USER_NAME>` to yours.

```
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      - system:node-proxier
      rolearn: arn:aws:iam::***********:role/eksctl-tokamak-optimism-go-FargatePodExecutionRole-1XH184K0CW6YD
      username: system:node:{{SessionName}}
  mapUsers: |
    # Add user for develop
    - userarn: arn:aws:iam::<ACCOUNT_ID>:user/<USER_NAME>
      username: <USER_NAME>
      groups:
        - developer
    # Add user for master
    - userarn: arn:aws:iam::<ACCOUNT_ID>:user/<USER_NAME>
      username: <USER_NAME>
      groups:
        - system:masters
    .
    .
    .
```

Also you can get own IAM information.

```
$ aws sts get-caller-identity
{
    "UserId": "AIDASI4G3********",
    "Account": "<ACCOUNT_ID>",
    "Arn": "arn:aws:iam::<ACCOUNT_ID>:user/<USER_NAME>"
}
```

### Change config

Modify environment variables.

```
./tokamak-optimism.sh update config
./tokamak-optimism.sh reload list
batch-submitter
relayer
data-transport-layer
l2geth

./tokamak-optimism.sh reload relayer
```

### Update Image

```
./tokamak-optimism.sh update list
config
batch-submitter
relayer
data-transport-layer
l2geth

./tokamak-optimism.sh tag
latest(2022-10-25T06:48:11.085338Z)
nightly(2022-10-27T07:38:14.018041Z)
release-0.1.1(2022-10-25T06:48:10.415968Z)
release-0.1.0(2022-10-17T08:49:47.894557Z)

./tokamak-optimism.sh update relayer latest
```

All resource can be update at once.

```
./tokamak-optimism.sh update all latest
```

The resource can be rollback.

```
./tokamak-optimism.sh update all undo
```

### Delete

Delete k8s resources

```
# in root directory

helm uninstall aws-load-balancer-controller -n kube-system

./tokamak-optimism.sh delete
```

Delete cluster and aws resources

```
eksctl delete iamserviceaccount --cluster=${cluster_name} --namespace=kube-system --name=aws-load-balancer-controller --region ${region}

eksctl delete iamserviceaccount --cluster=${cluster_name} --namespace=kube-system --name=efs-csi-controller-sa --region ${region}

# all efs mount targets must be removed before removing the file system.
# you can get mount target id following command
aws efs describe-mount-targets --file-system-id ${file_system_id} --region ${region} --query MountTargets[].MountTargetId

# delete mount-target. you have to execute this command for each mount target.
aws efs delete-mount-target --mount-target-id <mount target id> --region ${region}

# delete security group used by efs file system
aws ec2 delete-security-group --group-id ${security_group_id} --region ${region}

# delete file system
aws efs delete-file-system --file-system-id ${file_system_id} --region ${region}

# delete ${replica_file_system_id} file system such as ${file_system_id}

# delete cluster
eksctl delete cluster --name ${cluster_name} --region ${region}

# if you lose terminal session when deleting cluster, you need to find some values such as $file_system_id, $security_group_id ​​through the aws console or aws cli.
```
