#! /bin/bash

set -e

# GITHUB OAUTH APP
# Teleport Non-Enterprise Cluster can only use github sso
CLIENT_ID=$1
CLIENT_SECRET=$2

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "Usage: $0 <client_id> <client_secret>"
    exit 1
fi

TEMP_CONNECTOR_FILE=/tmp/github-connector.yaml
ROLE_FILE=./script/teleport-k3s-admin-role.yaml

echo "Creating role resource via definition in \"$ROLE_FILE\"..."
cat $ROLE_FILE | tctl create -f

echo "Configuring github sso on teleport cluster..."
tctl sso configure github \
  --id $CLIENT_ID \
  --secret $CLIENT_SECRET \
  --teams-to-roles=nori-cloud,teleport-admins,access,editor,k3s-admin \
  > $TEMP_CONNECTOR_FILE

cat $TEMP_CONNECTOR_FILE | tctl create -f

echo "Done configuring auth on teleport cluster."
