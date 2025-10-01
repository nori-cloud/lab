#! /bin/bash

set -e

if [ -f .env ]; then
    echo "📃 Loading .env file..."
    source .env
fi

# GITHUB OAUTH APP
# Teleport Non-Enterprise Cluster can only use github sso

if [ -z "$TELEPORT_OAUTH_CLIENT_ID" ] || [ -z "$TELEPORT_OAUTH_CLIENT_SECRET" ]; then
    echo "Missing TELEPORT_OAUTH_CLIENT_ID or TELEPORT_OAUTH_CLIENT_SECRET in env"
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
