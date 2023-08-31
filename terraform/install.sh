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
CLUSTER_LIST=$(ls $MYPATH/terraform.tfstate.d | xargs)

function check_cluster() {
  for i in $CLUSTER_LIST; do
    [[ "$i" == "$1" ]] && return 0
  done
  return 1
}

function ask_going() {
  terraform workspace select $CLUSTER_NAME
  local current_workspace=$(terraform workspace show)

  local message="Current workspace is \"${current_workspace}\"."$'\n'
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

if !(ask_going); then
  echo "aborted."
  exit 0
fi

terraform init
execcmd="terraform apply -var-file $MYPATH/environment/${CLUSTER_NAME}.tfvars -auto-approve"
echo $execcmd
eval $execcmd
