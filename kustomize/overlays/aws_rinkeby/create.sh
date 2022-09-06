#!/bin/bash

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ENVFILE=$MYPATH/.env
AWSENVPATH=$MYPATH/../../envs/aws

echo "Running create shell... \c"

if [ -f $ENVFILE ]; then
  export $(cat ${ENVFILE} | sed 's/#.*//g' | xargs)
else
  echo "Not found .env file($ENVFILE)"
  echo "Generate .env file from .env.example"
  exit 1
fi

envsubst '$EFS_VOLUME_ID' < $MYPATH/pv.yaml.template | cat > $MYPATH/pv.yaml
envsubst '$CERTIFICATE_ARN' < $MYPATH/ingress.yaml.template | cat > $MYPATH/ingress.yaml
envsubst '$AWS_EKS_CLUSTER_NAME,$AWS_VPC_ID,$AWS_REGION' < $AWSENVPATH/aws.env.template | cat > $AWSENVPATH/aws.env

echo "done"
