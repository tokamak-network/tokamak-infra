#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 mainnet"
  echo "  $0 goerli"
  echo "  $0 goerli-nightly"
  echo
}

CLUSTER_NAME=$1
MYPATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"
CLUSTER_LIST=$(ls $MYPATH/override_values | xargs)
KUBECTL="kubectl"

function check_cluster() {
  for i in $CLUSTER_LIST; do
    [[ "$i" == "$1" ]] && return 0
  done
  return 1
}

function ask_going() {
  local current_context=$(kubectl config current-context)

  if [[ -z $current_context ]]; then
    echo "confirm your KUBECONFIG value. got the '$KUBECONFIG'"
    exit 1
  fi

  local message="Current context is \"${current_context}\"."$'\n'
  message+="going to install?"
  local res=1
  read -p "$message (n) " -n 1 -r
  echo
  echo
  [[ $REPLY =~ ^[Yy]$ ]] && res=0
  return $res
}

if !(check_cluster $CLUSTER_NAME); then
  print_help
  exit 1
fi

if [[ ! -z "$KUBECONFIG" ]]; then
  KUBECTL="$KUBECTL --kubeconfig $KUBECONFIG"
  echo "KUBECONFIG applied"
fi

if !(ask_going); then
  echo "aborted."
  exit 0
fi

helm_file_list="-f $MYPATH/override_values/${CLUSTER_NAME}/values.yaml"
execcmd="helm upgrade -i -n argocd --create-namespace $helm_file_list argocd argo/argo-cd"
execcmd_application="$KUBECTL apply -k  $MYPATH/override_values/${CLUSTER_NAME}/applications"
echo $execcmd
eval $execcmd
eval $execcmd_application
