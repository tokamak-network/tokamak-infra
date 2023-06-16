# ECK (Elastic Cloud on Kubernetes)

### Fargate Profile(AWS)

If you want to deploy to AWS EKS, argocd profile should be created.
Check `aws cli` before run next command.

```
eksctl create fargateprofile \
    --cluster ${cluster_name} \
    --region ${region} \
    --name log-monitoring \
    --namespace log-monitoring
```

Example:

```
eksctl create fargateprofile \
    --cluster tokamak-optimism-goerli-nightly \
    --region ap-northeast-2 \
    --name log-monitoring \
    --namespace log-monitoring
```

### Add log-monitoring stack to cluster

```
kubectl apply -k kustomize/overlays/${cluster environment}
# example kubectl apply -k kustomize/overlays/aws/goerli-nightly
```
