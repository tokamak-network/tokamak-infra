#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 [command] ([cluster_name] [env_name]|[pod_name])"
  echo "    * command list"
  echo "      - create [list|cluster_name env_name]"
  echo "      - delete"
  echo "      - update"
  echo "      - reload(restart) [list|all|pod_name]"
  echo
  echo "Examples: "
  echo " $0 create list"
  echo " $0 create hardhat-remote local"
  echo " $0 delete"
  echo " $0 update"
  echo " $0 reload list"
  echo " $0 reload all"
  echo " $0 reload batch-submitter"
  echo
}

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ACTION=$1
ENV_LIST=$(ls -d $MYPATH/kustomize/overlays/*/ | rev | cut -f2 -d'/' |rev)

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

function configmap() {
  local configmap=$1
  local key=$2

  if [[ "$configmap" && "$key" ]]; then
    echo $(kubectl get cm $configmap -o "jsonpath={.data}" | jq -r .$key)
  fi
}

function get_configmap() {
  CONFIGMAP_CLUSTER_NAME=$(configmap "chain-config" "CLUSTER_NAME")
  CONFIGMAP_ENV_NAME=$(configmap "chain-config" "ENV_NAME")

  if [[ -z "$CONFIGMAP_CLUSTER_NAME" || -z "$CONFIGMAP_ENV_NAME" ]]; then
    echo "Error: failed to get cluster informations"
    exit 1
  fi

  echo "[Configmaps]"
  echo "* CLUSTER_NAME=${CONFIGMAP_CLUSTER_NAME}"
  echo "* ENV_NAME=${CONFIGMAP_ENV_NAME}"
}

function update_configmap() {
  kubectl apply -k $MYPATH/kustomize/envs/${CONFIGMAP_CLUSTER_NAME}
  if [ $? -ne 0 ]; then
    echo "Error: failed to run update_configmap()"
    exit 1
  fi
}

function rollout_restart() {
  local kind=$1
  local name=$2
  echo $1 $2
  if [[ -z "$kind" || -z "$name" ]]; then
    echo "Error: there is no arguments for rollout restart."
    exit 1
  fi

  echo "Restart $kind $name..."

  kubectl rollout restart $kind $name
  if [ $? -ne 0 ]; then
    echo "Error: failed to run rollout_restart()"
    exit 1
  fi
}

function get_pod_list() {
  local kind=$1

  if [ -z "$kind" ]; then
    echo "Error: there is no arguments to get pod list."
    exit 1
  fi

  pod_names=$(kubectl get $kind -o jsonpath='{.items[*].metadata}' | jq -r .name | grep -v -e '^app-')
  echo $pod_names
}

function print_create_list() {
  echo "[List that can be created]"
  for env in $ENV_LIST; do
    cluster_list=$(ls -d $MYPATH/kustomize/overlays/${env}/*/ | rev | cut -f2 -d'/' | rev)
    cluster_list=${cluster_list//templates/}
    for cluster in $cluster_list; do
      echo "* $cluster $env"
    done
  done
}

function print_running_list() {
  deployment_list=$(get_pod_list deployments)
  statefulset_list=$(get_pod_list statefulsets)

  echo "[List]"
  for pod in $deployment_list; do
    echo "* $pod"
  done
  for pod in $statefulset_list; do
    echo "* $pod"
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
  create)
    if [ "$2" == "list" ]; then
      print_create_list
      exit 0
    fi

    cluster_name=$2
    env_name=$3

    CLUSTER_LIST=$(ls -d $MYPATH/kustomize/overlays/${env_name}/*/ | rev | cut -f2 -d'/' | rev)
    CLUSTER_LIST=${CLUSTER_LIST/templates/}
    cluster_path=$MYPATH/kustomize/overlays/${env_name}/${cluster_name}

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

    secret_file=$MYPATH/kustomize/envs/$cluster_name/secret.env

    message="Do you check environment files?"$'\n'
    [ "$env_name" == "aws" ] && message+=" - $cluster_path/.env"$'\n'
    message+=" - $secret_file"$'\n'
    read -p "$message(n) " -n 1 -r
    echo
    if ! [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "aborted."
      exit 0
    fi

    if [ ! -f $secret_file ]; then
      echo "Not found secret.env file($secret_file)"
      echo "Generate secret.env file from secret.env.example"
      exit 1
    fi

    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    if [ -f $cluster_path/create.sh ]; then
      sh $cluster_path/create.sh
      if [ $? -ne 0 ]; then
        echo "Error: failed to run $cluster_path/create.sh"
        exit 1
      fi
    fi
    kubectl apply -k $cluster_path
    ;;
  delete)
    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    get_configmap

    delete_cluster_path=$MYPATH/kustomize/overlays/${CONFIGMAP_ENV_NAME}/${CONFIGMAP_CLUSTER_NAME}
    kubectl delete -k $delete_cluster_path
    if [ -f $delete_cluster_path/delete.sh ]; then
      sh $delete_cluster_path/delete.sh
      if [ $? -ne 0 ]; then
        echo "Error: failed to run $delete_cluster_path/delete.sh"
        exit 1
      fi
    fi
    ;;
  update|upgrade)
    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    get_configmap
    update_configmap
    ;;
  reload|restart)
    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    if [ -z "$2" ]; then
      print_help
      exit 1
    fi

    if [ "$2" == "list" ]; then
      print_running_list
      exit 0
    fi

    deployment_list=$(get_pod_list deployments)
    statefulset_list=$(get_pod_list statefulsets)

    if [ "$2" == "all" ];then
      for pod in $deployment_list; do
        rollout_restart deployment $pod
      done

      for pod in $statefulset_list; do
        rollout_restart statefulset $pod
      done
    else
      res=0
      for pod in $deployment_list; do
        if [ "$2" == $pod ]; then
          rollout_restart deployment $pod
          res=1
        fi
      done

      for pod in $statefulset_list; do
        if [ "$2" == $pod ]; then
          rollout_restart statefulset $pod
          res=1
        fi
      done

      if [ $res == 0 ]; then
        echo "Error: could not find pods ($2)"
        print_running_list
        exit 1
      fi
    fi
    ;;
  *)
    print_help
    exit 1
    ;;
esac
