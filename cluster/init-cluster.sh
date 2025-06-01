#!/bin/bash

set -e

echo "checking aws credentials..."
aws sts get-caller-identity

echo "initializing terraform..."
terraform init

echo "planning terraform..."
terraform plan

echo "applying terraform..."
terraform apply -auto-approve

echo "setting up kubectl..."
aws eks --region $(terraform output -raw region) update-kubeconfig \
    --name $(terraform output -raw cluster_name)
