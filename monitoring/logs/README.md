# ECK (Elastic Cloud on Kubernetes)

### Fargate Profile(AWS)

If you want to deploy to AWS EKS, argocd profile should be created.
Check `aws cli` before run next command.

```
eksctl create fargateprofile \
    --cluster ${cluster_name} \
    --region ${region} \
    --name elastic-stack \
    --namespace elastic-stack
```

Example:

```
eksctl create fargateprofile \
    --cluster tokamak-optimism-goerli-nightly \
    --region ap-northeast-2 \
    --name elastic-stack \
    --namespace elastic-stack
```

### Add elastic-stack to cluster

```
helm repo add elastic https://helm.elastic.co && helm repo update


kubectl create namespace elastic-stack

kubectl apply -k kustomize/overlays/${cluster environment}
# example kubectl apply -k kustomize/overlays/aws/goerli-nightly
```
