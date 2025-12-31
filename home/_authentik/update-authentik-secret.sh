#!/bin/bash

set -e

NAMESPACE=authentik
SECRET_NAME=authentik-credentials

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
[ -z "$AUTHENTIK_POSTGRES_HOST" ] && MISSING_VARS="$MISSING_VARS AUTHENTIK_POSTGRES_HOST"
[ -z "$AUTHENTIK_POSTGRES_NAME" ] && MISSING_VARS="$MISSING_VARS AUTHENTIK_POSTGRES_NAME"
[ -z "$AUTHENTIK_POSTGRES_USER" ] && MISSING_VARS="$MISSING_VARS AUTHENTIK_POSTGRES_USER"
[ -z "$AUTHENTIK_POSTGRES_PASSWORD" ] && MISSING_VARS="$MISSING_VARS AUTHENTIK_POSTGRES_PASSWORD"
[ -z "$AUTHENTIK_SECRET_KEY" ] && MISSING_VARS="$MISSING_VARS AUTHENTIK_SECRET_KEY"

if [ -n "$MISSING_VARS" ]; then
    echo "Missing required environment variables:$MISSING_VARS"
    echo "Set these in .env file"
    exit 1
fi

echo "Updating secret: $NAMESPACE/$SECRET_NAME"

# Build JSON for kubectl patch using printf for proper special char handling
B64_HOST=$(printf '%s' "$AUTHENTIK_POSTGRES_HOST" | base64 -w0)
B64_NAME=$(printf '%s' "$AUTHENTIK_POSTGRES_NAME" | base64 -w0)
B64_USER=$(printf '%s' "$AUTHENTIK_POSTGRES_USER" | base64 -w0)
B64_PASS=$(printf '%s' "$AUTHENTIK_POSTGRES_PASSWORD" | base64 -w0)
B64_KEY=$(printf '%s' "$AUTHENTIK_SECRET_KEY" | base64 -w0)

JSON_DATA=$(printf '{"postgres_host":"%s","postgres_name":"%s","postgres_user":"%s","postgres_password":"%s","secret_key":"%s"}' \
    "$B64_HOST" "$B64_NAME" "$B64_USER" "$B64_PASS" "$B64_KEY")

echo "Checking if secret exists..."
if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" > /dev/null 2>&1; then
    echo "Found existing secret, updating..."
    kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":$JSON_DATA}"
    echo "Secret patched successfully"
else
    echo "Creating secret..."
    kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" \
        --from-literal=postgres_host="$AUTHENTIK_POSTGRES_HOST" \
        --from-literal=postgres_name="$AUTHENTIK_POSTGRES_NAME" \
        --from-literal=postgres_user="$AUTHENTIK_POSTGRES_USER" \
        --from-literal=postgres_password="$AUTHENTIK_POSTGRES_PASSWORD" \
        --from-literal=secret_key="$AUTHENTIK_SECRET_KEY"
    echo "Secret created successfully"
fi

echo ""
echo "Current secret keys:"
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]'
