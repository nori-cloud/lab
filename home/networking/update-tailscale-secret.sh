#!/bin/bash

set -e

if [ -f .env ]; then
    echo "📃 Loading .env file..."
    source .env
fi

NAMESPACE=networking
SECRET_NAME=operator-oauth

if [ -z "$TAILSCALE_OAUTH_CLIENT_ID" ] || [ -z "$TAILSCALE_OAUTH_CLIENT_SECRET" ]; then
    echo "🔑 Need to set TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_OAUTH_CLIENT_SECRET in .env"
    exit 1
else
    echo "🔑 Found all required tokens..."
fi

echo "🔎 Checking if secret exists..."
if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" > /dev/null 2>&1; then
    echo "🔑 Found existing secret, patching..."
    kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type merge -p "{\"stringData\":{\"client_id\":\"$TAILSCALE_OAUTH_CLIENT_ID\",\"client_secret\":\"$TAILSCALE_OAUTH_CLIENT_SECRET\"}}"

    echo "🔑 Secret patched"
else
    echo "🔑 Creating secret..."
    kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" \
        --from-literal=client_id="$TAILSCALE_OAUTH_CLIENT_ID" \
        --from-literal=client_secret="$TAILSCALE_OAUTH_CLIENT_SECRET"
    echo "🔑 Secret created"
fi

echo ""
echo "✅ Done! Tailscale OAuth credentials configured in namespace $NAMESPACE"
echo ""
echo "Verify with:"
echo "  kubectl get secret $SECRET_NAME -n $NAMESPACE"
echo ""
echo "View secret keys (values are hidden):"
echo "  kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data}' | jq 'keys'"
