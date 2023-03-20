#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 [command]"
  echo "    * commands"
  echo "      - create"
  echo "         - list"
  echo "         - [app_name] [cluster_name] [env_name]"
  echo "      - delete"
  echo "         - list|[app_name]"
  echo "      - tag|tags [app_name]"
  echo "      - update"
  echo "         - list"
  echo "         - [app_name] config|[tag_name]|undo|list"
  echo "      - reload(restart)"
  echo "         - list|all|[app_name]"
  echo
  echo "Examples: "
  echo " $0 create list"
  echo " $0 create gateway hardhat local"
  echo " $0 create gateway goerli-nightly aws"
  echo " $0 delete list"
  echo " $0 delete gateway"
  echo " $0 tag gateway"
  echo " $0 update list"
  echo " $0 update gateway config"
  echo " $0 update gateway latest"
  echo " $0 update gateway undo"
  echo " $0 update gateway list"
  echo " $0 reload list"
  echo " $0 reload all"
  echo " $0 reload gateway"
  echo
}

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ACTION=$1
APP_NAME=$2
APP_LIST=$(ls -d $MYPATH/*/ | rev | cut -f2 -d'/' | rev)

while [[ $# -gt 0 ]]
do
  option="$1"
  case $option in
    -n)
      NAMESPACE="$2"
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}"

NAMESPACE_STR="-n app-${APP_NAME}"
[[ $NAMESPACE ]] && NAMESPACE_STR="-n $NAMESPACE"

if [[ -z "$ACTION" || -z "$APP_NAME" ]]; then
  print_help
  exit 1
fi

function check_cluster() {
  for i in $CLUSTER_LIST; do
    [[ "$i" == "$1" ]] && return 0
  done
  return 1
}

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
  deployment_list=$(get_resource_list deployments)
  statefulset_list=$(get_resource_list statefulsets)

  for name in $deployment_list; do
    [[ "$name" == "app-$1" ]] && return 0
  done

  for name in $statefulset_list; do
    [[ "$name" == "app-$1" ]] && return 0
  done

  return 1
}

function print_create_list() {
  for app in $APP_LIST; do
    if [ -d "$MYPATH/${app}/kustomize/overlays" ]; then
      env_list=$(ls -d $MYPATH/${app}/kustomize/overlays/*/ | rev | cut -f2 -d'/' | rev)
      for env in $env_list; do
        cluster_list=$(ls -d $MYPATH/${app}/kustomize/overlays/${env}/*/ | rev | cut -f2 -d'/' | rev)
        for cluster in $cluster_list; do
          echo "* $app $env $cluster"
        done
      done
    fi
  done
}

function print_running_list() {
  deployment_list=$(get_resource_list deployments)
  statefulset_list=$(get_resource_list statefulsets)

  if [[ ! -z "$deployment_list" || ! -z "$statefulset_list" ]]; then
    for name in $deployment_list; do
      echo "${name:4}"
    done
  fi
}

function configmap() {
  local configmap=$1
  local key=$2

  if [[ "$configmap" && "$key" ]]; then
    echo $(kubectl get cm $configmap $NAMESPACE_STR -o "jsonpath={.data}" | jq -r .$key)
  fi
}

function get_configmap() {
  CONFIGMAP_APP_NAME=$(configmap "app-${APP_NAME}-config" "APP_NAME")
  CONFIGMAP_ENV_NAME=$(configmap "app-${APP_NAME}-config" "ENV_NAME")
  CONFIGMAP_CLUSTER_NAME=$(configmap "app-${APP_NAME}-config" "CLUSTER_NAME")

  if [[ -z "$CONFIGMAP_APP_NAME" || -z "$CONFIGMAP_ENV_NAME" || -z "$CONFIGMAP_CLUSTER_NAME" ]]; then
    echo "Error: failed to get app informations"
    exit 1
  fi

  echo "[Configmaps]"
  echo "* APP_NAME=${CONFIGMAP_APP_NAME}"
  echo "* ENV_NAME=${CONFIGMAP_ENV_NAME}"
  echo "* CLUSTER_NAME=${CONFIGMAP_CLUSTER_NAME}"
}

function get_resource_list() {
  local kind=$1

  if [ -z "$kind" ]; then
    echo "Error: there is no arguments to get pod list."
    exit 1
  fi

  pod_names=$(kubectl get $kind $NAMESPACE_STR -o jsonpath='{.items[*].metadata}' | jq -r .name | grep -e '^app-')
  echo $pod_names
}

function get_resource_image() {
  local name=$1

  if [ -z "$name" ]; then
    echo "Error: there is no arguments to get resource image."
    exit 1
  fi

  res=$(kubectl get pods $NAMESPACE_STR -o json | jq -c '[ .items|.[]|.spec.containers|.[] | select( .name | contains("'app-${name}'")) ]' | jq -r .[0].image)
  arr=(${res//:/ })
  echo ${arr[0]}
}

function update_configmap() {
  kubectl apply -k $MYPATH/${APP_NAME}/kustomize/overlays/${CONFIGMAP_ENV_NAME}/${CONFIGMAP_CLUSTER_NAME}
  if [ $? -ne 0 ]; then
    echo "Error: failed to run update_configmap()"
    exit 1
  fi
}

function update_image() {
  local kind=$1
  local name=$2
  local tagname=$3

  if [[ -z "$kind" || -z "$name" || -z "$tagname" ]]; then
    echo "Error: there is no arguments for update image."
    exit 1
  fi

  echo "Starting update ${name:4} $kind to $tagname..."
  sleep 1

  local image=$(get_resource_image ${name:4})
  local is_tag=0
  local tags=$(get_tags $image)

  for tag in $tags; do
    [[ "$tagname" == "$tag" || "$tagname" == "undo" ]] && is_tag=1 && break
  done

  if [ "$is_tag" == 0 ]; then
    echo "Error: could not find tag name($tagname) on '$image'"
    exit 1
  fi

  if [[ "$kind" == "deployment" || "$kind" == "deploy" ]]; then
    if [ $tagname == "undo" ]; then
      kubectl $NAMESPACE_STR rollout undo $kind/$name
    else
      kubectl $NAMESPACE_STR set image $kind/$name $name=$image:$tagname
    fi
  elif [[ "$kind" == "statefulset" || "$kind" == "sts" ]]; then
    if [ $tagname == "undo" ]; then
      echo "Warning: statefulset($name) is not supported undo!"
    else
      kubectl $NAMESPACE_STR patch statefulset $name --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"'${image}':'${tagname}'"}]'
    fi
  else
    echo "Error: Wrong resource kind: $kind"
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

  kubectl rollout restart $kind $name $NAMESPACE_STR
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

function get_tags() {
  local image=$1
  if [ -z "$image" ]; then
    echo "Error: there is no arguments to get tags."
    exit 1
  fi

  local tags=$(curl -s https://hub.docker.com/v2/repositories/${image}/tags/?page_size=1000 | jq -r '.results|.[]|"\(.name)"')
  echo $tags
}

case $ACTION in
  tag|tags)
    image=$(get_resource_image $APP_NAME)

    if [ -z "$image" ]; then
      echo "Error: could not find $APP_NAME image."
      echo "$APP_NAME should be already created."
      exit 1
    fi

    tags=$(get_tags $image)
    for tag in $tags; do
      echo $tag
      # [[ "$tag" =~ ^release|^nightly|^latest ]] && echo $tag
    done
    ;;

  create)
    if [ "$2" == "list" ]; then
      print_create_list
      exit 0
    fi

    env_name=$3
    cluster_name=$4
    app_path=$MYPATH/${APP_NAME}/kustomize/overlays/${env_name}
    ENV_LIST=$(ls -d ${app_path}/../*/ | rev | cut -f2 -d'/' | rev)
    CLUSTER_LIST=$(ls -d ${app_path}/*/ | rev | cut -f2 -d'/' | rev)
    cluster_path=$app_path/${cluster_name}

    if !(check_app $APP_NAME); then
      print_help
      print_create_list
      exit 1
    fi

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

    kubectl apply -k $cluster_path
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

    delete_app_path=$MYPATH/${APP_NAME}/kustomize/overlays/${CONFIGMAP_ENV_NAME}/${CONFIGMAP_CLUSTER_NAME}

    kubectl delete -k $delete_app_path
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

    if [ -z "$3" ]; then
      echo "Error: write tag version you want to update or write 'config'"
      exit 1
    fi

    if [[ "$3" =~ ^config$|^configmap$ ]]; then
      if !(ask_going); then
        echo "aborted."
        exit 0
      fi
      get_configmap
      update_configmap
    else
      image=$(get_resource_image $APP_NAME)
      tagname=$3

      if [ "$tagname" == "list" ]; then
        tags=$(get_tags $image)
        for tag in $tags; do
          echo $tag
        done
        exit 0
      else
        if !(ask_going); then
          echo "aborted."
          exit 0
        fi
        deployment_list=$(get_resource_list deployments)
        statefulset_list=$(get_resource_list statefulsets)
        res=0
        for name in $deployment_list; do
          if [ "app-$APP_NAME" == $name ]; then
            update_image deployment $name $tagname
            res=1
          fi
        done

        for name in $statefulset_list; do
          if [ "app-$APP_NAME" == $name ]; then
            update_image statefulset $name $tagname
            res=1
          fi
        done

        if [ $res == 0 ]; then
          echo "Error: could not find resource ($APP_NAME)"
          print_running_list
          exit 1
        fi
      fi
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
    deployment_list=$(get_resource_list deployments)
    statefulset_list=$(get_resource_list statefulsets)

    if [[ "$APP_NAME" == "all" ]];then
      for name in $deployment_list; do
        rollout_restart deployment $name
      done

      for name in $statefulset_list; do
        rollout_restart statefulset $name
      done
    else
      for name in $deployment_list; do
        if [ "app-$APP_NAME" == $name ]; then
          rollout_restart deployment $name
          res=1
        fi
      done

      for name in $statefulset_list; do
        if [ "app-$APP_NAME" == $name ]; then
          rollout_restart statefulset $name
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
