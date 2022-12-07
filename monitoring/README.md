# Monitoring

## Prerequisite

### Helm

Install `helm`

## Set Variables for Cluster

### for Local

```
cluster=local
```

### for AWS Goerli

```
cluster=aws-goerli
```

### for AWS Goerli Nightly

```
cluster=aws-goerli-nightly
```

## Install Prometheus Stack

```
helm install -n monitoring --create-namespace -f override_values/base.yaml -f override_values/${cluster}.yaml -f override_values/alert-rules.yaml tokamak-optimism-monitoring prometheus-community/kube-prometheus-stack
```

## Add Grafana Dashboards

```
kubectl apply -k dashboards
```

## Connect Prometheus/Grafana

### for Local

- prometheus: http://localhost:9090
- grafana: http://localhost:3000

### for AWS

- prometheus: use `Port Forwarding`
- grafana: https://goerli-nightly.grafana.tokamak.network or https://goerli.grafana.tokamak.network

## Upgrade Promethes Stack

```
helm upgrade -n monitoring --create-namespace -f override_values/base.yaml -f override_values/${cluster}.yaml -f override_values/alert-rules.yaml tokamak-optimism-monitoring prometheus-community/kube-prometheus-stack
```

## Uninstall Promethes STack

```
helm uninstall -n monitoring tokamak-optimism-monitoring
```

## Grafana Account

```
grafana_user=$(kubectl get secret prometheus-stack-grafana -o jsonpath="{.data.admin-user}" -n monitoring |base64 -d; echo)

grafana_password=$(kubectl get secret prometheus-stack-grafana -o jsonpath="{.data.admin-password}" -n monitoring |base64 -d; echo)

echo $grafana_user
echo $grafana_password
```

## Next Step

- Persistent Volumes
- 3rd APM Service
- Advanced Application Monitoring
