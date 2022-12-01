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

## Add Dashboards
```
kubectl apply -k dashboards
```

## Install Prometheus Stack

```
helm install -n monitoring --create-namespace -f override_values/base.yaml -f override_values/local.yaml prometheus-stack prometheus-community/kube-prometheus-stack
```

## Upgrade Promethes Stack

```
helm upgrade -n monitoring --create-namespace -f override_values/base.yaml -f override_values/local.yaml prometheus-stack prometheus-community/kube-prometheus-stack
```

## Uninstall Promethes STack

```
helm uninstall -n monitoring prometheus-stack
```

## Grafana Account

```
export grafana_user=$(kubectl get secret prometheus-stack-grafana -o jsonpath="{.data.admin-user}" -n monitoring |base64 -d; echo)

export grafana_password=$(kubectl get secret prometheus-stack-grafana -o jsonpath="{.data.admin-password}" -n monitoring |base64 -d; echo)
```

## Next Step

- Ingress for aws
- Persistent Volumes
- 3rd APM Service
- Advanced Application Monitoring
