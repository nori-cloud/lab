#! /bin/bash

set -e

CLIENT_ID=$(echo -n "$1" | base64 -w0)
CLIENT_SECRET=$(echo -n "$2" | base64 -w0)

NAMESPACE=system
SECRET_NAME=argocd-oauth-client


if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "Usage: $0 <client_id> <client_secret>"
    exit 1
fi

echo "🔎 Checking if secret exists..."
if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" > /dev/null 2>&1; then
    echo "🔑 Found existing secret, patching..."
    kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":{\"client-id\":\"$CLIENT_ID\",\"client-secret\":\"$CLIENT_SECRET\"}}"
    echo "🔑 Secret patched"
else
    echo "🔑 Creating secret..."
    kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" --from-literal=client-id="$CLIENT_ID" --from-literal=client-secret="$CLIENT_SECRET"
    echo "🔑 Secret created"
fi
