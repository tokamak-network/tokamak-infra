# Monitoring

## Prerequisite

### Helm

Install `helm`

### Namaspace

Create `monitoring` namespace to cluster

```
kubectl get namespace

kubectl create namespace monitoring
```

## Run Prometheus Stack

```
helm install -n monitoring --create-namespace -f override_values/base.yaml -f override_values/aws.yaml prometheus-stack prometheus-community/kube-prometheus-stack
```

## Next Step

- Ingress
- Persistent Volumes
- 3rd APM Service
- Advanced Application Monitoring
