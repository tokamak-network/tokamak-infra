# Redis

### Fargate Profile(AWS)

If you want to deploy to AWS EKS, argocd profile should be created.
Check `aws cli` before run next command.

```
eksctl create fargateprofile \
    --cluster ${cluster_name} \
    --region ${region} \
    --name postgresql \
    --namespace postgresql
```

Example:

```
eksctl create fargateprofile \
    --cluster tokamak-optimism-goerli-nightly \
    --region ap-northeast-2 \
    --name postgresql \
    --namespace postgresql
```

### Add postgresql to cluster

```
kubectl apply -k postgresql/kustomize/overlays/aws/goerli

kubectl apply -k postgresql/kustomize/overlays/aws/goerli-nightly
```
