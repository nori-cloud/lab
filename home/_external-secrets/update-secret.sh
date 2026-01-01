#!/bin/bash

set -e

NAMESPACE=external-secrets
SECRET_NAME=infisical-universal-auth

if [ -f .env ]; then
    echo "Loading .env file..."
    # Read .env without expanding special characters like $
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        # Remove surrounding quotes if present
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        # Export the variable without expansion
        export "$key=$value"
    done < .env
fi

MISSING_VARS=""
[ -z "$INFISICAL_CLIENT_ID" ] && MISSING_VARS="$MISSING_VARS INFISICAL_CLIENT_ID"
[ -z "$INFISICAL_CLIENT_SECRET" ] && MISSING_VARS="$MISSING_VARS INFISICAL_CLIENT_SECRET"

if [ -n "$MISSING_VARS" ]; then
    echo "Missing required environment variables:$MISSING_VARS"
    echo "Set these in .env file"
    exit 1
fi

echo "Updating secret: $NAMESPACE/$SECRET_NAME"

# Build JSON for kubectl patch using printf for proper special char handling
B64_CLIENT_ID=$(printf '%s' "$INFISICAL_CLIENT_ID" | base64 -w0)
B64_CLIENT_SECRET=$(printf '%s' "$INFISICAL_CLIENT_SECRET" | base64 -w0)

JSON_DATA=$(printf '{"client_id":"%s","client_secret":"%s"}' \
    "$B64_CLIENT_ID" "$B64_CLIENT_SECRET")

echo "Checking if secret exists..."
if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" > /dev/null 2>&1; then
    echo "Found existing secret, updating..."
    kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":$JSON_DATA}"
    echo "Secret patched successfully"
else
    echo "Secret does not exists. Have you applied 'module.external_secrets'?"
fi

echo ""
echo "Current secret keys:"
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]'
