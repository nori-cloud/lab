#!/bin/bash

set -e

NAMESPACE=nori-cloud
SECRET_NAME=ghcr-image-pull-secret

echo "📝 Image Pull Secret Updater for nori-cloud"
echo ""

# Check if credentials are provided via environment variables
if [ -z "$GHCR_USERNAME" ] || [ -z "$GHCR_PAT" ]; then
    echo "🔑 GHCR_USERNAME and GHCR_PAT not found in environment"
    echo ""
    echo "Please provide GitHub Container Registry credentials:"
    read -p "GitHub Username: " GHCR_USERNAME
    read -sp "GitHub PAT (Personal Access Token): " GHCR_PAT
    echo ""
fi

if [ -z "$GHCR_USERNAME" ] || [ -z "$GHCR_PAT" ]; then
    echo "❌ Error: GHCR_USERNAME and GHCR_PAT are required"
    exit 1
fi

echo "🔑 Generating docker config..."

# Create the docker config JSON
DOCKER_CONFIG=$(echo -n "$GHCR_USERNAME:$GHCR_PAT" | base64 -w0)
DOCKER_CONFIG_JSON=$(cat <<EOF
{
  "auths": {
    "ghcr.io": {
      "auth": "$DOCKER_CONFIG"
    }
  }
}
EOF
)

# Base64 encode the entire docker config
DOCKER_CONFIG_JSON_BASE64=$(echo -n "$DOCKER_CONFIG_JSON" | base64 -w0)

echo "🔎 Checking if secret exists..."
if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" > /dev/null 2>&1; then
    echo "🔑 Found existing secret, patching..."
    kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":{\".dockerconfigjson\":\"$DOCKER_CONFIG_JSON_BASE64\"}}"
    echo "✅ Secret patched successfully"
else
    echo "🔑 Creating new secret..."
    kubectl create secret docker-registry "$SECRET_NAME" \
        -n "$NAMESPACE" \
        --docker-server=ghcr.io \
        --docker-username="$GHCR_USERNAME" \
        --docker-password="$GHCR_PAT"
    echo "✅ Secret created successfully"
fi

echo ""
echo "🎉 Image pull secret updated for namespace: $NAMESPACE"
