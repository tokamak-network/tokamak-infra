# ArgoCD

## Prerequisite

### Helm

* [https://helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/)
* add helm chart repository

```
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Fargate Profile(AWS)

If you want to deploy to AWS EKS, argocd profile should be created.
Check `aws cli` before run next command.

```
eksctl create fargateprofile \
    --cluster ${cluster_name} \
    --region ${region} \
    --name argocd \
    --namespace argocd
```

Example:

```
eksctl create fargateprofile \
    --cluster tokamak-optimism-goerli-nightly \
    --region ap-northeast-2 \
    --name argocd \
    --namespace argocd
```

## Create .env file

### for Local

```
cp override_values/.env.local override_values/.env
```

### for AWS Goerli

```
cp override_values/.env.goerli override_values/.env
```

### for AWS Goerli Nightly

```
cp override_values/.env.goerli-nightly override_values/.env
```

## Install ArgoCD

### for aws

```
./install.sh aws
```

### for local

```
./install.sh local
```

### Get admin password

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | xargs
```

## Uninstall ArgoCD

```
./delete.sh
```
