#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 [command] [app name] [env name]"
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
APP_NAME=$2
ENV_NAME=$3

if [[ -z "$ACTION" || -z "$APP_NAME" || -z "$ENV_NAME" ]]; then
  print_help
  exit 1
fi

APP_PATH=$MYPATH/${APP_NAME}/kustomize/overlays/${ENV_NAME}
APP_LIST=$(ls -d $MYPATH/*/ | rev | cut -f2 -d'/' | rev)
ENV_LIST=$(ls -d $APP_PATH/../*/ | rev | cut -f2 -d'/' | rev)

function check_app() {
  for i in $APP_LIST; do
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

if !(check_app $APP_NAME); then
  print_help
  echo -e "\nError: wrong app name($APP_NAME)"
  echo "App List:"
  for i in $APP_LIST; do echo - ${i%%/}; done
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
echo "* APP_NAME=${APP_NAME}"
echo "* ENV_NAME=${ENV_NAME}"
echo

if [ $ACTION == "create" ]; then
  if [ -f $APP_PATH/create.sh ]; then
    sh $APP_PATH/create.sh
    [ $? -ne 0 ] && exit 1
  fi
  kubectl apply -k $APP_PATH

elif [ $ACTION == "delete" ]; then
  kubectl delete -k $APP_PATH
  if [ -f $APP_PATH/delete.sh ]; then
    sh $APP_PATH/delete.sh
    [ $? -ne 0 ] && exit 1
  fi
else
  print_help
  exit 1
fi
