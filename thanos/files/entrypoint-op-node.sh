#!/bin/sh
set -exu

wget \
    "${OP_NODE_ROLLUP_CONFIG_URL}" \
    -q \
    -O rollup.json

exec op-node \
    --rollup.config=./rollup.json \
    --safedb.path=/safedb
    "$@"
