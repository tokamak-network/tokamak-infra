#!/bin/bash -e

function print_help() {
  echo "Usage: "
  echo "  $0"
  echo
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

execcmd="helm delete -n argocd argocd"
eval $execcmd
