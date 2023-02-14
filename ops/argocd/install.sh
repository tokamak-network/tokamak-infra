#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0 aws"
  echo "  $0 local"
  echo
}

ENV_NAME=$1
MYPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
OVERRIDE_PATH=$MYPATH/override_values
ENV_FILE=$OVERRIDE_PATH/.env

function check_env() {
  local env_name=$1

  if [[ "$env_name" != "local" && "$env_name" != "aws" ]]; then
    echo "Error: wrong ENV_NAME!!"
    return 1
  fi
  return 0
}

function ask_going() {
  local current_context=$(kubectl config current-context)
  local message="Current context is \"${current_context}\"."$'\n'
  message+="going to install?"
  local res=1
  read -p "$message (n) " -n 1 -r
  echo
  echo
  [[ $REPLY =~ ^[Yy]$ ]] && res=0
  return $res
}

if !(check_env $ENV_NAME); then
  print_help
  exit 1
fi

if [ -f "$ENV_FILE" ]; then
  export $(cat ${ENV_FILE} | sed 's/#.*//g' | xargs)
else
  echo "ERROR: Can't not find .env file($ENV_FILE)"
  echo "Generate .env file"
  exit 1
fi

message="Do you check environment files?"$'\n'
message+=" - $ENV_FILE"$'\n'
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

helm_file_list="-f $OVERRIDE_PATH/base.yaml"

if [ "$ENV_NAME" == "aws" ]; then
  template_file=$OVERRIDE_PATH/aws.yaml.template
  generated_file=$OVERRIDE_PATH/aws.yaml

  if [ ! -f "$template_file" ]; then
    echo "Error: Can't find template file: $template_file"
    exit 1
  fi
  envsubst '$CERTIFICATE_ARN,$HOST_NAME' < $template_file | cat > $generated_file

  helm_file_list+=" -f $OVERRIDE_PATH/$ENV_NAME.yaml"
fi

execcmd="helm install -n argocd --create-namespace $helm_file_list argocd argo/argo-cd"
eval $execcmd
