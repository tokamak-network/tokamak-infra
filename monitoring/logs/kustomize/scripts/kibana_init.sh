#!/bin/bash

url="http://localhost:5601/api/status"
search_string='"savedObjects":{"level":"available",'

until curl -u "init_scripts:${ELASTIC_PASSWORD}" -sb -H "Accept: application/json" "$url" | grep -q "$search_string"; do
    sleep 1
done

dashboard_response_code=$(curl -s -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
    -u "init_scripts:${ELASTIC_PASSWORD}" \
    --header 'kbn-xsrf: true' \
    --form file=@dashboards/savedObjects.ndjson \
    -o /dev/null \
    -w '%{http_code}')

if [ "$dashboard_response_code" -eq 200 ]; then
    echo "success to import dashbaord!"
else
    echo "failed to import dashbaord."
fi

config_response_code=$(curl -s -X PUT 'http://localhost:5601/api/saved_objects/config/8.8.0' \
    -u "init_scripts:${ELASTIC_PASSWORD}" \
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
