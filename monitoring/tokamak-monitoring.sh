#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 [command] ([env_name])"
  echo "    * command"
  echo "      - create"
  echo "        - list"
  echo "        - [cluster_name] [env_name]"
  echo "      - update"
  echo "      - delete"
  echo
}

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
OVERRIDE_PATH=$MYPATH/override_values
VOLUME_PATH=$MYPATH/volume
ACTION=$1
ENV_LIST=$(ls -d $MYPATH/override_values/*/ | rev | cut -f2 -d'/' |rev)
HELM_NAMESPACE=monitoring

if [ -z "$ACTION" ]; then
  print_help
  exit 1
fi

function check_cluster() {
  for i in $CLUSTER_LIST; do
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

function print_create_list() {
  echo "[List that can be created]"
  for env in $ENV_LIST; do
    cluster_list=$(ls -d $MYPATH/override_values/${env}/*/ | rev | cut -f2 -d'/' | rev)
    for cluster in $cluster_list; do
      echo "* $cluster $env"
    done
  done
}

function ask_going() {
  local current_context=$(kubectl config current-context)
  local message="Current context is \"${current_context}\"."$'\n'
  message+="going to \"${ACTION}\"?"
  local res=1
  read -p "$message (n) " -n 1 -r
  echo
  echo
  [[ $REPLY =~ ^[Yy]$ ]] && res=0
  return $res
}

case $ACTION in
  create|install|upgrade|update)
    if [ "$2" == "list" ]; then
      print_create_list
      exit 0
    fi

    cluster_name=$2
    env_name=$3

    CLUSTER_LIST=$(ls -d $MYPATH/override_values/${env_name}/*/ | rev | cut -f2 -d'/' | rev)

    if !(check_cluster $cluster_name); then
      print_help
      print_create_list
      exit 1
    fi

    if !(check_env $env_name); then
      print_help
      print_create_list
      exit 1
    fi

    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    cmd=install
    [[ $ACTION == "upgrade" || $ACTION == "update" ]] && cmd=upgrade

    env_path=$OVERRIDE_PATH/${env_name}/${cluster_name}

    if [ ! -f "${env_path}/resources.yaml" ]; then
      echo "Error: Can't find helm file: ${env_path}/resources.yaml"
      exit 1
    fi

    execcmd="kubectl apply -k dashboards"
    echo $execcmd
    eval $execcmd

    if [ -f "${env_path}/pv.yaml" ]; then
      execcmd="kubectl apply -f ${env_path}/pv.yaml"
      echo $execcmd
      eval $execcmd
    fi

    helm_file_list="-f $env_path/base.yaml -f $env_path/alert-rules.yaml -f $env_path/resources.yaml"

    execcmd="helm $cmd -n $HELM_NAMESPACE --create-namespace $helm_file_list tokamak-optimism-monitoring prometheus-community/kube-prometheus-stack"
    echo $execcmd
    eval $execcmd

    helm_file_list="-f $env_path/blackbox.yaml"

    execcmd="helm $cmd -n $HELM_NAMESPACE $helm_file_list blackbox-exporter prometheus-community/prometheus-blackbox-exporter"
    echo $execcmd
    eval $execcmd
    ;;

  delete|remove|uninstall)
    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    cluster_name=$2
    env_name=$3
    env_path=$OVERRIDE_PATH/${env_name}/${cluster_name}

    execcmd="helm delete -n $HELM_NAMESPACE tokamak-optimism-monitoring"
    echo $execcmd
    eval $execcmd

    execcmd="helm delete -n $HELM_NAMESPACE blackbox-exporter"
    echo $execcmd
    eval $execcmd

    execcmd="kubectl delete -k dashboards"
    echo $execcmd
    eval $execcmd

    if [ -f "${env_path}/pv.yaml" ]; then
      execcmd="kubectl delete -f ${env_path}/pv.yaml"
      echo $execcmd
      eval $execcmd
    fi
    ;;
  *)
    print_help
    exit 1
    ;;
esac
