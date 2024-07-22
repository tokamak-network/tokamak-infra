#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 [command]"
  echo "    * commands"
  echo "      - create"
  echo "         - list"
  echo "         - [cluster_name] [env_name]"
  echo "      - delete"
  echo "      - tag|tags ([resource])"
  echo "      - update"
  echo "         - config|list"
  echo "         - all [tag_name]|undo"
  echo "         - [resource] [tag_name]|undo"
  echo "         - [resource] list"
  echo "      - reload(restart)"
  echo "         - list|all|[resource]"
  echo
  echo "Examples: "
  echo " $0 create list"
  echo " $0 create hardhat-remote local"
  echo " $0 delete"
  echo " $0 tag"
  echo " $0 tag batch-submitter"
  echo " $0 update config"
  echo " $0 update list"
  echo " $0 update all release-1.0.1"
  echo " $0 update all undo"
  echo " $0 update batch-submitter release-1.0.1"
  echo " $0 update batch-submitter undo"
  echo " $0 update batch-submitter list"
  echo " $0 reload list"
  echo " $0 reload all"
  echo " $0 reload batch-submitter"
  echo
}

MYPATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"
ACTION=$1
ENV_LIST=$(ls -d $MYPATH/kustomize/overlays/*/ | rev | cut -f2 -d'/' | rev)

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

function update_image() {
  local kind=$1
  local name=$2
  local tagname=$3

  if [[ -z "$kind" || -z "$name" || -z "$tagname" ]]; then
    echo "Error: there is no arguments for update image."
    exit 1
  fi

  echo "Starting update $name $kind to $tagname..."
  sleep 1

  local image=$(get_resource_image $name)
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
      kubectl rollout undo $kind/$name
    else
      kubectl set image $kind/$name $name=$image:$tagname
    fi
  elif [[ "$kind" == "statefulset" || "$kind" == "sts" ]]; then
    if [ $tagname == "undo" ]; then
      echo "Warning: statefulset($name) is not supported undo!"
    else
      kubectl patch statefulset $name --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"'${image}':'${tagname}'"}]'
    fi
  else
    echo "Error: Wrong resource kind: $kind"
    exit 1
  fi
}

function rollout_restart() {
  local kind=$1
  local name=$2

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

function get_resource_list() {
  local kind=$1

  if [ -z "$kind" ]; then
    echo "Error: there is no arguments to get resource list."
    exit 1
  fi

  pod_names=$(kubectl get $kind -o jsonpath='{.items[*].metadata}' | jq -r .name | grep -v -e '^app-')
  echo $pod_names
}

function get_resource_image() {
  local name=$1

  if [ -z "$name" ]; then
    echo "Error: there is no arguments to get resource image."
    exit 1
  fi

  res=$(kubectl get pods -o json | jq -c '[ .items|.[]|.spec.containers|.[] | select( .name | contains("'${name}'")) ]' | jq -r .[0].image)
  arr=(${res//:/ })
  echo ${arr[0]}
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
  deployment_list=$(get_resource_list deployments)
  statefulset_list=$(get_resource_list statefulsets)

  for name in $deployment_list; do
    echo "$name"
  done
  for name in $statefulset_list; do
    echo "$name"
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
tag | tags)
  if [ -z "$2" ]; then
    image="tokamaknetwork/titan-l2geth"
    tags=$(get_tags $image)
    for tag in $tags; do
      [[ "$tag" =~ ^release|^nightly$|^latest ]] && echo $tag
    done
  else
    image=$(get_resource_image $2)
    if [ -z "$image" ]; then
      echo "Error: could not find $2 image."
      echo "$2 should be already created."
      exit 1
    fi
    tags=$(get_tags $image)
    for tag in $tags; do
      echo $tag
    done
  fi
  ;;
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
  ;;
update | upgrade)
  deployment_list=$(get_resource_list deployments)
  statefulset_list=$(get_resource_list statefulsets)

  if [ "$2" == "list" ]; then
    [[ ! -z "$deployment_list" || ! -z "$statefulset_list" ]] && echo config
    for name in $deployment_list; do
      echo $name
    done
    for name in $statefulset_list; do
      echo $name
    done
    exit 0
  fi

  if [[ "$2" =~ ^config$|^configmap$ ]]; then
    if !(ask_going); then
      echo "aborted."
      exit 0
    fi
    get_configmap
    update_configmap
  else
    image=$(get_resource_image $2)
    tagname=$3
    if [ -z "$tagname" ]; then
      print_help
      echo "Error: write tag version you want to update!"
      echo "You can show tags as running '$0 tag'"
      exit 1
    elif [ "$tagname" == "list" ]; then
      tags=$(get_tags $image)
      for tag in $tags; do
        echo $tag
      done
      exit 0
    fi

    if !(ask_going); then
      echo "aborted."
      exit 0
    fi
    if [ "$2" == "all" ]; then
      for name in $deployment_list; do
        update_image deployment $name $tagname
      done

      for name in $statefulset_list; do
        update_image statefulset $name $tagname
      done
    else
      res=0
      for name in $deployment_list; do
        if [ "$2" == $name ]; then
          update_image deployment $name $tagname
          res=1
        fi
      done

      for name in $statefulset_list; do
        if [ "$2" == $name ]; then
          update_image statefulset $name $tagname
          res=1
        fi
      done

      if [ $res == 0 ]; then
        echo "Error: could not find resource ($2)"
        print_running_list
        exit 1
      fi
    fi
  fi
  ;;
reload | restart)
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

  deployment_list=$(get_resource_list deployments)
  statefulset_list=$(get_resource_list statefulsets)

  if [ "$2" == "all" ]; then
    for name in $deployment_list; do
      rollout_restart deployment $name
    done

    for name in $statefulset_list; do
      rollout_restart statefulset $name
    done
  else
    res=0
    for name in $deployment_list; do
      if [ "$2" == $name ]; then
        rollout_restart deployment $name
        res=1
      fi
    done

    for name in $statefulset_list; do
      if [ "$2" == $name ]; then
        rollout_restart statefulset $name
        res=1
      fi
    done

    if [ $res == 0 ]; then
      echo "Error: could not find resource ($2)"
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
