#!/bin/bash -e

ACTION=$1
ACTION_LIST=("create delete")
CLUSTER_NAME=$2
CLUSTER_LIST=$(ls -d kustomize/overlays/*/ | cut -f3 -d'/')
CLUSTER_PATH=kustomize/overlays/${CLUSTER_NAME}

function print_help() {
  echo "Usage: "
  echo "  $0 [command] [cluster name]"
  echo "    * command list"
  echo "    - create"
  echo "    - delete"
}

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

if !(check_action $ACTION); then
  print_help
  exit 1
fi

if !(check_cluster $CLUSTER_NAME); then
  print_help
  echo -e "\nError: wrong cluster name( $CLUSTER_NAME )"
  echo "Cluster List:"
  for i in $CLUSTER_LIST; do echo ${i%%/}; done
  exit 1
fi

NETWORK=${CLUSTER_NAME##*_}

echo "* ACTION=${ACTION}"
echo "* CLUSTER_NAME=${CLUSTER_NAME}"
echo "* NETWORK=${NETWORK}"
echo

SECRET_FILE=./kustomize/envs/$NETWORK/secret.env

if [ ! -f $SECRET_FILE ]; then
  echo "Not found secret.env file($SECRET_FILE)"
  echo "Generate secret.env file from secret.env.example"
  exit 1
fi

if [ $ACTION == "create" ]; then
  if [ -f $CLUSTER_PATH/create.sh ]; then
    sh $CLUSTER_PATH/create.sh
  fi
  kubectl apply -k $CLUSTER_PATH

elif [ $ACTION == "delete" ]; then
  kubectl delete -k $CLUSTER_PATH
  if [ -f $CLUSTER_PATH/delete.sh ]; then
    sh $CLUSTER_PATH/delete.sh
  fi
else
  print_help
  exit 1
fi
