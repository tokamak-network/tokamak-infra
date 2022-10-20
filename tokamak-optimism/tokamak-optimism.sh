#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 [command] [cluster name] [env name]"
  echo "    * command list"
  echo "      - create"
  echo "      - delete"
  echo "      - list"
  echo "    * env list"
  echo "      - aws"
  echo "      - local"
}

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ACTION=$1
ACTION_LIST=("create delete list")
CLUSTER_NAME=$2
ENV_NAME=$3

if [[ -z "$ACTION" ]]; then
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

function get_configmap() {
  local configmap=$1
  local key=$2

  if [[ "$configmap" && "$key" ]]; then
    echo $(kubectl get cm $configmap -o "jsonpath={.data}" | jq -r .$key)
  fi
}

if !(check_action $ACTION); then
  print_help
  exit 1
fi

echo "[ARGS]"
echo "* ACTION=${ACTION}"
echo "* CLUSTER_NAME=${CLUSTER_NAME}"
echo "* ENV_NAME=${ENV_NAME}"
echo

if [ $ACTION == "list" ]; then
  echo "[List that can be created]"
  for env in $ENV_LIST; do
    cluster_list=$(ls -d $MYPATH/kustomize/overlays/${env}/*/ | rev | cut -f2 -d'/' | rev)
    cluster_list=${cluster_list//templates/}
    for cluster in $cluster_list; do
      echo "* $cluster $env"
    done
  done
  exit 0
fi

if [ $ACTION == "create" ]; then
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

  SECRET_FILE=$MYPATH/kustomize/envs/$CLUSTER_NAME/secret.env

  if [ ! -f $SECRET_FILE ]; then
    echo "Not found secret.env file($SECRET_FILE)"
    echo "Generate secret.env file from secret.env.example"
    exit 1
  fi

  if [ -f $CLUSTER_PATH/create.sh ]; then
    sh $CLUSTER_PATH/create.sh
    [ $? -ne 0 ] && exit 1
  fi
  kubectl apply -k $CLUSTER_PATH

elif [ $ACTION == "delete" ]; then
  CONFIGMAP_CLUSTER_NAME=$(get_configmap "chain-config" "CLUSTER_NAME")
  CONFIGMAP_ENV_NAME=$(get_configmap "chain-config" "ENV_NAME")

  if [[ -z "$CONFIGMAP_CLUSTER_NAME" || -z "$CONFIGMAP_ENV_NAME" ]]; then
    echo "Error: failed to get cluster informations"
    exit 1
  fi

  echo "[Configmaps]"
  echo "* CLUSTER_NAME=${CONFIGMAP_CLUSTER_NAME}"
  echo "* ENV_NAME=${CONFIGMAP_ENV_NAME}"

  DELETE_CLUSTER_PATH=$MYPATH/kustomize/overlays/${CONFIGMAP_ENV_NAME}/${CONFIGMAP_CLUSTER_NAME}
  kubectl delete -k $DELETE_CLUSTER_PATH
  if [ -f $DELETE_CLUSTER_PATH/delete.sh ]; then
    sh $DELETE_CLUSTER_PATH/delete.sh
    [ $? -ne 0 ] && exit 1
  fi
else
  print_help
  exit 1
fi
