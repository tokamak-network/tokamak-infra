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

### What init process do (difference with common elastic stack)

**elasticsearch**

```
ulimit -n 65535
ulimit -u 65535
```

elasticsearch needs at least 65535 file descriptors. and at least 4096 number of threads. you can see details https://www.elastic.co/guide/en/elasticsearch/reference/8.8/max-number-of-threads.html.

init_password.sh

```
#!/bin/bash
until curl -u "elastic:${ELASTIC_PASSWORD}" -s -f -o /dev/null "http://127.0.0.1:9200/_cluster/health?wait_for_status=yellow&timeout=1s"
do
    sleep 1
done

printf 'y\n%s\n%s\n' "$ELASTIC_PASSWORD" "$ELASTIC_PASSWORD" | bin/elasticsearch-reset-password -u kibana_system -i

curl  --location --request PUT 'http://127.0.0.1:9200/_settings' \
        -u "elastic:${ELASTIC_PASSWORD}" \
        --header 'Content-Type: application/json' \
        --data '{"index": {"number_of_replicas": 0}}'
```

The `init_password.sh` initializes the password of the built-in user `kibana_system`. and set the base setting `number_of_replicas` of the every index to 0. because the elasticsearch is consist of single, it can't have replicas.

**kibana**

init.sh

```
#!/bin/bash

url="http://localhost:5601/api/status"
search_string='"savedObjects":{"level":"available",'

until curl -u "elastic:${ELASTIC_PASSWORD}" -sb -H "Accept: application/json" "$url" | grep -q "$search_string"; do
    sleep 1
done

dashbaord_response_code=$(curl -s -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
    -u "elastic:${ELASTIC_PASSWORD}" \
    --header 'kbn-xsrf: true' \
    --form file=@scripts/dashboard.ndjson \
    -o /dev/null \
    -w '%{http_code}')

if [ "$dashbaord_response_code" -eq 200 ]; then
    echo "success to import dashbaord!"
else
    echo "failed to import dashbaord."
fi

config_response_code=$(curl -s -X PUT 'http://localhost:5601/api/saved_objects/config/8.8.0' \
    -u "elastic:${ELASTIC_PASSWORD}" \
    --header 'kbn-xsrf: true;' \
    --header 'Content-Type: application/json' \
    --data '{
        "attributes": {
            "discover:sampleSize": "5000"
        }
    }' \
    -o /dev/null \
    -w '%{http_code}')

if [ "$config_response_code" -eq 200 ]; then
    echo "success to set discover:sampleSize!"
else
    echo "failed to set discover:sampleSize."
fi
```

The `init.sh` adds `dashboard` included `search` and `index-pattern` components of kibana and sets the config `discover:sampleSize`.
