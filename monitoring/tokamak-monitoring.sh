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
OVERRIDE_PATH=$MYPATH/override_values
VOLUME_PATH=$MYPATH/volume
ACTION=$1
ENV_NAME=$2
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

function generate_helm_files() {
  local env_name=$1
  local env_file=$OVERRIDE_PATH/.env

  if [ -f "$env_file" ]; then
    export $(cat ${env_file} | sed 's/#.*//g' | xargs)
  else
    echo "ERROR: Can't not find .env file($env_file)"
    echo "Generate .env file"
    exit 1
  fi

  if [ "$env_name" == "aws" ]; then
    template_file=$OVERRIDE_PATH/aws.yaml.template
    generated_file=$OVERRIDE_PATH/aws.yaml

    if [ ! -f "$template_file" ]; then
      echo "Error: Can't find template file: $template_file"
      exit 1
    fi
    envsubst '$CERTIFICATE_ARN,$HOST_NAME' < $template_file | cat > $generated_file

    template_file=$VOLUME_PATH/pv.yaml.template
    generated_file=$VOLUME_PATH/pv.yaml

    if [ ! -f "$template_file" ]; then
      echo "Error: Can't find template file: $template_file"
      exit 1
    fi
    envsubst '$EFS_VOLUME_ID' < $template_file | cat > $generated_file
  fi

  template_file=$OVERRIDE_PATH/alert-rules.yaml.template
  generated_file=$OVERRIDE_PATH/alert-rules.yaml

  if [ ! -f "$template_file" ]; then
    echo "Error: Can't find template file: $template_file"
    exit 1
  fi

  envsubst '$L1_ADDR,$SLACK_API_URL,$SLACK_CHANNEL,$CLUSTER_NAME' < $template_file | cat > $generated_file

  template_file=$OVERRIDE_PATH/base.yaml.template
  generated_file=$OVERRIDE_PATH/base.yaml

  if [ ! -f "$template_file" ]; then
    echo "Error: Can't find template file: $template_file"
    exit 1
  fi

  envsubst '$L1_ADDR' < $template_file | cat > $generated_file
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
    if !(check_env $ENV_NAME); then
      print_help
      exit 1
    fi

    message="Do you check environment files?"$'\n'
    message+=" - $OVERRIDE_PATH/.env"$'\n'
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

    generate_helm_files $ENV_NAME

    cmd=install
    [[ $ACTION == "upgrade" || $ACTION == "update" ]] && cmd=upgrade

    if [ ! -f "$OVERRIDE_PATH/$ENV_NAME.yaml" ]; then
      echo "Error: Can't find helm file: $OVERRIDE_PATH/$ENV_NAME.yaml"
      exit 1
    fi

    kubectl apply -k dashboards
    kubectl apply -f $VOLUME_PATH/pv.yaml

    helm_file_list="-f $OVERRIDE_PATH/base.yaml -f $OVERRIDE_PATH/alert-rules.yaml -f $OVERRIDE_PATH/$ENV_NAME.yaml"

    execcmd="helm $cmd -n $HELM_NAMESPACE --create-namespace $helm_file_list tokamak-optimism-monitoring prometheus-community/kube-prometheus-stack"
    eval $execcmd

    helm_file_list="-f $OVERRIDE_PATH/blackbox.yaml"

    execcmd="helm $cmd -n $HELM_NAMESPACE $helm_file_list blackbox-exporter prometheus-community/prometheus-blackbox-exporter"
    eval $execcmd
    ;;
  delete|remove|uninstall)
    if !(ask_going); then
      echo "aborted."
      exit 0
    fi

    execcmd="helm delete -n $HELM_NAMESPACE tokamak-optimism-monitoring"
    eval $execcmd

    execcmd="helm delete -n $HELM_NAMESPACE blackbox-exporter"
    eval $execcmd

    kubectl delete -k dashboards
    kubectl delete -f $VOLUME_PATH/pv.yaml
    ;;
  *)
    print_help
    exit 1
    ;;
esac
