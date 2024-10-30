#!/bin/sh
set -exu

wget \
    "${OP_CHALLENGER_CANNON_ROLLUP_CONFIG_URL}" \
    -q \
    -O rollup.json

wget \
	  "${OP_CHALLENGER_CANNON_L2_GENESIS_URL}" \
	  -q \
	  -O l2-genesis.json

exec op-challenger \
    --cannon-rollup-config=./rollup.json \
    --cannon-l2-genesis=./l2-genesis.json \
    "$@"
