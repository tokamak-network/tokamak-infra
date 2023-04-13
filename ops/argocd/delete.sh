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

execcmd="helm delete -n argocd argocd"
eval $execcmd
