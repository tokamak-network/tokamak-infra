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
  message+="going to \"${ACTION}\"?"
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

execcmd_application="$KUBECTL delete -k  $MYPATH/override_values/${CLUSTER_NAME}/applications"
execcmd="helm delete -n argocd argocd"
eval $execcmd_application
eval $execcmd
