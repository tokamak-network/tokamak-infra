#!/bin/bash

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ENVFILE=$MYPATH/.env

echo "Running create shell... \c"

if [ -f $ENVFILE ]; then
  export $(cat ${ENVFILE} | sed 's/#.*//g' | xargs)
else
  echo "Not found .env file($ENVFILE)"
  echo "Generate .env file from .env.example"
  exit 1
fi

envsubst '$EFS_VOLUME_ID' < $MYPATH/../templates/pv.yaml.template | cat > $MYPATH/pv.yaml
envsubst '$CERTIFICATE_ARN' < $MYPATH/../templates/ingress.yaml.template | cat > $MYPATH/ingress.yaml

echo "done"
