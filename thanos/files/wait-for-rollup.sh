#!/bin/bash
set -eou
if [[ -z $L2_ROLLUP_WEB3_URL ]]; then
    echo "Must pass L2_ROLLUP_WEB3_URL"
    exit 1
fi
JSON='{"jsonrpc":"2.0","method":"optimism_rollupConfig","params":[],"id":1}'
echo "Waiting for Rollup"
curl \
    -X POST \
    --header 'Content-Type: application/json' \
    --silent \
    --output /dev/null \
    --retry-connrefused \
    --retry 1000 \
    --retry-delay 1 \
    -d "$JSON" \
    $L2_ROLLUP_WEB3_URL
echo "Connected to Rollup"