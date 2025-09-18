#! /bin/bash

set -e

CLIENT_ID=$1
CLIENT_SECRET=$2

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "Usage: $0 <client_id> <client_secret>"
    exit 1
fi

echo "⚙️ Updating client ID..."
kubectl get configmap argocd-cm -n system -o yaml > /tmp/argocd-cm.yaml
sed -i "s/argocd_oauth_client_id/$CLIENT_ID/g" /tmp/argocd-cm.yaml
kubectl apply -f /tmp/argocd-cm.yaml
echo "⚙️ Client ID updated"


echo "🔑 Updating client secret..."
CLIENT_SECRET_BASE64=$(printf %s "$CLIENT_SECRET" | base64 -w0)
PATCH_PAYLOAD=$(printf '{"data":{"dex.authentik.clientSecret":"%s"}}' "$CLIENT_SECRET_BASE64")
kubectl patch secret argocd-secret -n system --type merge -p "$PATCH_PAYLOAD"
echo "🔑 Client secret updated"
