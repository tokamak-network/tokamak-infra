#!/bin/bash

until curl -u "init_scripts:${ELASTIC_PASSWORD}" -s -f -o /dev/null "http://127.0.0.1:9200/_cluster/health?wait_for_status=yellow&timeout=1s"; do
    sleep 1
done

printf 'y\n%s\n%s\n' "$ELASTIC_PASSWORD" "$ELASTIC_PASSWORD" | bin/elasticsearch-reset-password -u kibana_system -i

curl --location --request PUT 'http://127.0.0.1:9200/_index_template/default' \
    -u "init_scripts:${ELASTIC_PASSWORD}" \
    --header 'Content-Type: application/json' \
    --data '{"index_patterns": ["*"], "template": {"settings": {"number_of_replicas": 0}}, "priority": 1}'
