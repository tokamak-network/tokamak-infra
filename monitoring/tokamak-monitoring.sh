#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 [command] ([env_name])"
  echo "    * command list"
  echo "      - create local"
  echo "      - create aws"
  echo "      - update local"
  echo "      - update aws"
  echo "      - delete"
  echo
}

MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ACTION=$1
ENV_NAME=$2
HELM_RELEASE=tokamak-optimism-monitoring
HELM_NAMESPACE=monitoring

function check_env() {
  local env_name=$1

  if [[ "$env_name" != "local" && "$env_name" != "aws" ]]; then
    echo "Error: wrong ENV_NAME!!"
    return 1
  fi
  # [[ "$env_name" != "local" && "$env_name" != "aws" ]] && return 1
  return 0
}

function generate_aws_helm_file() {
  local template_path=$MYPATH/override_values
  local template_file=$template_path/aws.yaml.template
  local env_file=$template_path/.env

  if [ ! -f "$template_file" ]; then
    echo "Error: Can't find template file: $template_file"
    exit 1
  fi

  if [ -f "$env_file" ]; then
    export $(cat ${env_file} | sed 's/#.*//g' | xargs)
  else
    echo "ERROR: Can't not find .env file($env_file)"
    echo "Generate .env file"
    exit 1
  fi

  envsubst '$CERTIFICATE_ARN,$HOST_NAME' < $template_file | cat > $template_path/aws.yaml
}

case $ACTION in
  create|install|upgrade|update)
    if !(check_env $ENV_NAME); then
      print_help
      exit 1
    fi

    if [ "$ENV_NAME" == "aws" ]; then
      message="Do you check environment files?"$'\n'
      message+=" - $MYPATH/.env"$'\n'
      read -p "$message(n) " -n 1 -r
      echo
      if ! [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "aborted."
        exit 0
      fi

      generate_aws_helm_file

      cmd=install
      [[ $ACTION == "upgrade" || $ACTION == "update" ]] && cmd=upgrade

      echo "$cmd"
      # helm $cmd -n $HELM_NAMESPACE --create-namespace -f override_vallues/base.yaml -f override_values/aws.yaml $HELM_RELEASE prometheus-community/kube-prometheus-stack
    fi
    ;;
  delete|remove|uninstall)
  # helm delete -n $HELM_NAMESPACE $HELM_RELEASE
    echo "helm delete -n $HELM_NAMESPACE $HELM_RELEASE"
    ;;
  *)
    print_help
    exit 1
    ;;
esac

#helm install -n monitoring --create-namespace -f override_values/base.yaml -f override_values/aws-goerli-nightly.yaml tokamak-optimism-monitoring prometheus-community/kube-prometheus-stack