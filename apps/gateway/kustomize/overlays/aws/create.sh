#!/bin/bash

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ENVFILE=$MYPATH/.env
CONFIG_FILE=$MYPATH/../../config/config.json

echo "Running create shell... \c"

if [ -f $ENVFILE ]; then
  export $(cat ${ENVFILE} | sed 's/#.*//g' | xargs)
else
  echo "Not found .env file($ENVFILE)"
  echo "Generate .env file from .env.example"
  exit 1
fi

if [ ! -f $CONFIG_FILE ]; then
  echo -e "\nError: Config file is not found."
  echo "Config file: $CONFIG_FILE"
  exit 1
fi

envsubst '$CERTIFICATE_ARN' < $MYPATH/ingress.yaml.template | cat > $MYPATH/ingress.yaml

echo "done"
