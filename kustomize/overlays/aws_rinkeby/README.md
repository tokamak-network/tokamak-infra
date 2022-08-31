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

### AWS EFS
AWS EFS is required.
- Create EFS with IAM following the [documentation](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/efs-csi.html). (Skip `Install the Amazon EFS driver` in the documentation)

### AWS Application Load Balancer
IAM for AWS Load Balancer Controller is required.
- Follow the [documentation](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/aws-load-balancer-controller.html). (Create up to the `2. Create an IAM role` step)

Some setting is required.
- Follow the [documentation](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html)

## Run
```
kustomize build . > /tmp/kustomize.yaml
export EFS_VOLUME_ID=fs-00000000000000000
export AWS_EFS_CSI_CONTROLLER_ROLE_ARN=arn:aws:iam::000000000000:role/RoleName
export AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN=arn:aws:iam::000000000000:role/RoleName
envsubst '$EFS_VOLUME_ID,$AWS_EFS_CSI_CONTROLLER_ROLE_ARN,$AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN' < /tmp/kustomize.yaml | kubectl apply -f -
```

If you see this error, run again `envsubst '$EFS_VOLUME_ID,$AWS_EFS_CSI_CONTROLLER_ROLE_ARN,$AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN' < /tmp/kustomize.yaml | kubectl apply -f -`.
```
Error from server (InternalError): error when creating "STDIN": Internal error occurred: failed calling webhook "webhook.cert-manager.io": failed to call webhook: Post "https://cert-manager-webhook.cert-manager.svc:443/mutate?timeout=30s": no endpoints available for service "cert-manager-webhook"
```
This is an error according to the resource creation order. We will fix this error.

## Delete
```
kustomize build . > /tmp/kustomize.yaml
export EFS_VOLUME_ID=fs-00000000000000000
export AWS_EFS_CSI_CONTROLLER_ROLE_ARN=arn:aws:iam::000000000000:role/RoleName
export AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN=arn:aws:iam::000000000000:role/RoleName
envsubst '$EFS_VOLUME_ID,$AWS_EFS_CSI_CONTROLLER_ROLE_ARN,$AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN' < /tmp/kustomize.yaml | kubectl delete --force -f -
```