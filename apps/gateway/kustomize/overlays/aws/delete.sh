#!/bin/bash

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ENVFILE=$MYPATH/.env

echo "Running delete shell... \c"

rm -f $MYPATH/ingress.yaml

echo "done"
