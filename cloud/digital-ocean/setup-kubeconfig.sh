#! /bin/bash

set -e

DO_CLUSTER_ID=$1
DO_TOKEN=$2

if [ -z "$DO_CLUSTER_ID" ] || [ -z "$DO_TOKEN" ]; then
  echo "Usage: $0 <DO_CLUSTER_ID> <DO_TOKEN>"
  exit 1
fi

if [ -z "$CI" ]; then
  doctl kubernetes cluster kubeconfig save $DO_CLUSTER_ID --access-token $DO_TOKEN
else
  echo "Skipping kubeconfig setup in CI"
fi