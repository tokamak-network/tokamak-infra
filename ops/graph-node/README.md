# Redis

### Fargate Profile(AWS)

If you want to deploy to AWS EKS, argocd profile should be created.
Check `aws cli` before run next command.

```
eksctl create fargateprofile \
    --cluster ${cluster_name} \
    --region ${region} \
    --name thegraph \
    --namespace thegraph
```

Example:

```
eksctl create fargateprofile \
    --cluster tokamak-optimism-goerli-nightly \
    --region ap-northeast-2 \
    --name thegraph \
    --namespace thegraph
```

### Add redis to cluster

```
kubectl apply -k kustomize/overlays/aws/mainnet
```
