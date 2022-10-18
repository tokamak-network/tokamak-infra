#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 [command] [cluster name] [env name]"
  echo "    * command list"
  echo "      - create"
  echo "      - delete"
  echo "    * env list"
  echo "      - aws"
  echo "      - local"
}

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ACTION=$1
ACTION_LIST=("create delete list")
CLUSTER_NAME=$2
ENV_NAME=$3

if [[ -z "$ACTION" || -z "$CLUSTER_NAME" || -z "$ENV_NAME" ]]; then
  print_help
  exit 1
fi

ENV_LIST=$(ls -d $MYPATH/kustomize/overlays/*/ | rev | cut -f2 -d'/' |rev)
CLUSTER_LIST=$(ls -d $MYPATH/kustomize/overlays/${ENV_NAME}/*/ | rev | cut -f2 -d'/' | rev)
CLUSTER_LIST=${CLUSTER_LIST//templates/}
CLUSTER_PATH=$MYPATH/kustomize/overlays/${ENV_NAME}/${CLUSTER_NAME}

function check_cluster() {
  for i in $CLUSTER_LIST; do
    [[ "$i" == "$1" ]] && return 0
  done
  return 1
}

function check_action() {
  for i in $ACTION_LIST; do
    [[ "$i" == "$1" ]] && return 0
  done
  return 1
}

function check_env() {
  for i in $ENV_LIST; do
    [[ "$i" == "$1" ]] && return 0
  done
  return 1
}

if !(check_action $ACTION); then
  print_help
  exit 1
fi

if !(check_cluster $CLUSTER_NAME); then
  print_help
  echo -e "\nError: wrong cluster name( $CLUSTER_NAME )"
  echo "Cluster List:"
  for i in $CLUSTER_LIST; do echo - ${i%%/}; done
  exit 1
fi

if !(check_env $ENV_NAME); then
  print_help
  echo -e "\nError: wrong env name($ENV_NAME)"
  echo "ENV List:"
  for i in $ENV_LIST; do echo - ${i%%/}; done
  exit 1
fi

echo "* ACTION=${ACTION}"
echo "* CLUSTER_NAME=${CLUSTER_NAME}"
echo "* ENV_NAME=${ENV_NAME}"
echo

SECRET_FILE=$MYPATH/kustomize/envs/$CLUSTER_NAME/secret.env

if [ ! -f $SECRET_FILE ]; then
  echo "Not found secret.env file($SECRET_FILE)"
  echo "Generate secret.env file from secret.env.example"
  exit 1
fi

if [ $ACTION == "create" ]; then
  if [ -f $CLUSTER_PATH/create.sh ]; then
    sh $CLUSTER_PATH/create.sh
    [ $? -ne 0 ] && exit 1
  fi
  kubectl apply -k $CLUSTER_PATH

elif [ $ACTION == "delete" ]; then
  kubectl delete -k $CLUSTER_PATH
  if [ -f $CLUSTER_PATH/delete.sh ]; then
    sh $CLUSTER_PATH/delete.sh
    [ $? -ne 0 ] && exit 1
  fi
else
  print_help
  exit 1
fi
