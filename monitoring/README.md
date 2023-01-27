# Monitoring

## Prerequisite

### Helm

* [https://helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/)
* add helm chart repository

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
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

## Install Prometheus Stack

### for aws

```
./tokamak-monitoring.sh create aws
```

### for local

```
./tokamak-monitoring.sh create local
```

## Connect Prometheus/Grafana

### for Local

- prometheus: http://localhost:9090
- grafana: http://localhost:3000

### for AWS

- prometheus: use `Port Forwarding`
- grafana: https://goerli-nightly.grafana.tokamak.network or https://goerli.grafana.tokamak.network

## Upgrade Promethes Stack

### for aws

```
./tokamak-monitoring.sh upgrade aws
```

### for local

```
./tokamak-monitoring.sh upgrade local
```

## Uninstall Promethes Stack

```
./tokamak-monitoring delete
```

## Grafana Account

default username is `admin` and default password is `admin`.

## Alert Manager

Create a slack webhook (https://api.slack.com/messaging/webhooks)

Modify slack informations in `.env`

```
SLACK_API_URL=xxxxx
SLACK_CHANNEL=xxxxx
```

## Next Step

- 3rd APM Service
- Advanced Application Monitoring
