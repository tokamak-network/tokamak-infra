#!/bin/bash
set -eou
if [[ -z $L1_NODE_WEB3_URL ]]; then
    echo "Must pass L1_NODE_WEB3_URL "
    exit 1
fi
JSON='{"jsonrpc":"2.0","id":0,"method":"eth_chainId","params":[]}'
echo "Waiting for L1"
curl \
    -X POST \
    --header 'Content-Type: application/json' \
    --silent \
    --retry-connrefused \
    --retry 1000 \
    --retry-delay 1 \
    -d "$JSON" \
    $L1_NODE_WEB3_URL
echo "Connected to L1"
