# Monitoring

## Prerequisite

### Fargate Profile(AWS)

If you want to deploy to AWS EKS, argocd profile should be created.
Check `aws cli` before run next command.

```
eksctl create fargateprofile \
    --cluster ${cluster_name} \
    --region ${region} \
    --name monitoring \
    --namespace monitoring
```

### Helm

- [https://helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/)
- add helm chart repository

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

## Install Prometheus Stack

### for aws goerli

```
./tokamak-monitoring.sh create aws goerli
```

### for aws goerli-nightly

```
./tokamak-monitoring.sh create aws goerli-nightly
```

## Connect Prometheus/Grafana

### for AWS

- prometheus: use `Port Forwarding`
- grafana: https://grafana.titan-goerli-nightly.tokamak.network or https://grafana.titan-goerli.tokamak.network

## Upgrade Promethes Stack

### for aws goerli

```
./tokamak-monitoring.sh upgrade aws goerli
```

### for aws goerli

```
./tokamak-monitoring.sh upgrade aws goerli-nightly
```

## Uninstall Promethes Stack

```
./tokamak-monitoring delete aws goerli
```

## Grafana Account

default username is `admin` and default password is `admin`.
