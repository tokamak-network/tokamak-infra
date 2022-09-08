#!/bin/bash

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ENVFILE=$MYPATH/.env
AWSENVPATH=$MYPATH/../../envs/aws

echo "Running delete shell... \c"

rm -f $MYPATH/pv.yaml
rm -f $MYPATH/ingress.yaml
rm -f $AWSENVPATH/aws.env

echo "done"
