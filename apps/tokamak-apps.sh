#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 [command] [app_name] [env_name]"
  echo "    * command list"
  echo "      - create [list|all|app_name env_name]"
  echo "      - delete [list|all|app_name]"
  echo "      - update [list|app_name]"
  echo "      - reload(restart) [list|all|app_name]"
  echo
  echo "Examples: "
  echo " $0 create list"
  echo " $0 create gateway local"
  echo " $0 delete list"
  echo " $0 delete gateway"
  echo " $0 update list"
  echo " $0 update gateway"
  echo " $0 reload list"
  echo " $0 reload all"
  echo " $0 reload gateway"
  echo
}

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ACTION=$1
APP_NAME=$2
APP_LIST=$(ls -d $MYPATH/*/ | rev | cut -f2 -d'/' | rev)

if [[ -z "$ACTION" || -z "$APP_NAME" ]]; then
  print_help
  exit 1
fi

function check_app() {
  for i in $APP_LIST; do
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

function check_running_pod() {
  deployment_list=$(get_pod_list deployments)
  statefulset_list=$(get_pod_list statefulsets)

  for pod in $deployment_list; do
    [[ "$pod" == "app-$1" ]] && return 0
  done

  for pod in $statefulset_list; do
    [[ "$pod" == "app-$1" ]] && return 0
  done

  return 1
}

function print_create_list() {
  echo "[List]"
  for app in $APP_LIST; do
    if [ -d "$MYPATH/${app}/kustomize/overlays" ]; then
      env_list=$(ls -d $MYPATH/${app}/kustomize/overlays/*/ | rev | cut -f2 -d'/' | rev)
      for env in $env_list; do
        echo "* $app $env"
      done
    fi
  done
}

function print_running_list() {
  deployment_list=$(get_pod_list deployments)
  statefulset_list=$(get_pod_list statefulsets)

  if [[ ! -z "$deployment_list" || ! -z "$statefulset_list" ]]; then
    echo "[List]"
    for pod in $deployment_list; do
      echo "* ${pod:4}"
    done
  fi
}

function configmap() {
  local configmap=$1
  local key=$2

  if [[ "$configmap" && "$key" ]]; then
    echo $(kubectl get cm $configmap -o "jsonpath={.data}" | jq -r .$key)
  fi
}

function get_configmap() {
  CONFIGMAP_APP_NAME=$(configmap "app-${APP_NAME}-config" "APP_NAME")
  CONFIGMAP_ENV_NAME=$(configmap "app-${APP_NAME}-config" "ENV_NAME")

  if [[ -z "$CONFIGMAP_APP_NAME" || -z "$CONFIGMAP_ENV_NAME" ]]; then
    echo "Error: failed to get app informations"
    exit 1
  fi

  echo "[Configmaps]"
  echo "* APP_NAME=${CONFIGMAP_APP_NAME}"
  echo "* ENV_NAME=${CONFIGMAP_ENV_NAME}"
}

function get_pod_list() {
  local kind=$1

  if [ -z "$kind" ]; then
    echo "Error: there is no arguments to get pod list."
    exit 1
  fi

  pod_names=$(kubectl get $kind -o jsonpath='{.items[*].metadata}' | jq -r .name | grep -e '^app-')
  echo $pod_names
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

    env_name=$3
    app_path=$MYPATH/${APP_NAME}/kustomize/overlays/${env_name}
    ENV_LIST=$(ls -d ${app_path}/../*/ | rev | cut -f2 -d'/' | rev)

    if !(check_app $APP_NAME); then
      print_help
      print_create_list
      exit 1
    fi

    if !(check_env $env_name); then
      print_help
      print_create_list
      exit 1
    fi

    # Add applications and config files
    declare -a config_apps=(
      "gateway"
    )
    declare -a config_files=(
      "$MYPATH/${APP_NAME}/config/config.json"
    )

    message="Do you check environment and config files?"$'\n'
    [ "$env_name" == "aws" ] && message+=" - $app_path/.env"$'\n'

    idx=0
    for app in ${config_apps[@]}; do
      if [ "$APP_NAME" == "$app" ]; then
        message+=" - ${config_files[$idx]}"$'\n'
      fi
      ((idx++))
    done

    read -p "$message(n) " -n 1 -r
    echo
    if ! [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "aborted."
      exit 0
    fi

    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    if [ -f $app_path/create.sh ]; then
      sh $app_path/create.sh
      if [ $? -ne 0 ]; then
        echo "Error: failed to run $app_path/create.sh"
        exit 1
      fi
    fi
    kubectl apply -k $app_path
    ;;
  delete)
    if [ "$2" == "list" ]; then
      print_running_list
      exit 0
    fi

    if !(check_running_pod $APP_NAME); then
      echo "Error: could not find app ($APP_NAME)"
      print_running_list
      exit 1
    fi

    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    get_configmap

    delete_app_path=$MYPATH/${APP_NAME}/kustomize/overlays/${CONFIGMAP_ENV_NAME}
    kubectl delete -k $delete_app_path
    if [ -f $delete_app_path/delete.sh ]; then
      sh $delete_app_path/delete.sh
      if [ $? -ne 0 ]; then
        echo "Error: failed to run $delete_app_path/delete.sh"
        exit 1
      fi
    fi
    ;;
  update|upgrade)
    if [ "$2" == "list" ]; then
      print_running_list
      exit 0
    fi

    if !(check_running_pod $APP_NAME); then
      echo "Error: could not find app ($APP_NAME)"
      print_running_list
      exit 1
    fi

    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    get_configmap

    kubectl apply -k $MYPATH/${APP_NAME}/kustomize/overlays/${CONFIGMAP_ENV_NAME}
    if [ $? -ne 0 ]; then
      echo "Error: failed to run update_configmap()"
      exit 1
    fi
    ;;
  reload|restart)
    if [ "$2" == "list" ]; then
      print_running_list
      exit 0
    fi

    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    res=0
    deployment_list=$(get_pod_list deployments)
    statefulset_list=$(get_pod_list statefulsets)

    if [[ "$APP_NAME" == "all" ]];then
      for pod in $deployment_list; do
        rollout_restart deployment $pod
      done

      for pod in $statefulset_list; do
        rollout_restart statefulset $pod
      done
    else
      for pod in $deployment_list; do
        if [ "app-$APP_NAME" == $pod ]; then
          rollout_restart deployment $pod
          res=1
        fi
      done

      for pod in $statefulset_list; do
        if [ "app-$APP_NAME" == $pod ]; then
          rollout_restart statefulset $pod
          res=1
        fi
      done

      if [ $res == 0 ]; then
        echo "Error: could not find app ($APP_NAME)"
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
