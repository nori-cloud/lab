#! /bin/bash

set -e

if [ -f .env ]; then
    echo "📃 Loading .env file..."
    source .env
fi

NAMESPACE=networking
SECRET_NAME=cert-manager-creds

if [ -z "$NORRISWU_ME_CF_DNS_TOKEN" ] || [ -z "$PAWMERY_PET_CF_DNS_TOKEN" ]; then
    echo "🔑 Need to set NORRISWU_ME_CF_DNS_TOKEN and PAWMERY_PET_CF_DNS_TOKEN in .env"
    exit 1
else
    echo "🔑 Found all required tokens... encoding..."
    NORRISWU_ME_CF_DNS_TOKEN=$(echo -n "$NORRISWU_ME_CF_DNS_TOKEN" | base64 -w0)
    PAWMERY_PET_CF_DNS_TOKEN=$(echo -n "$PAWMERY_PET_CF_DNS_TOKEN" | base64 -w0)
    echo "🔑 Encoded tokens..."
fi

echo "🔎 Checking if secret exists..."
if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" > /dev/null 2>&1; then
    echo "🔑 Found existing secret, patching..."
    kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":{\"norriswu_me_cf_dns_token\":\"$NORRISWU_ME_CF_DNS_TOKEN\",\"pawmery_pet_cf_dns_token\":\"$PAWMERY_PET_CF_DNS_TOKEN\"}}"

    echo "🔑 Secret patched"
else
    echo "🔑 Creating secret..."
    kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" --from-literal=norriswu_me_cf_dns_token="$NORRISWU_ME_CF_DNS_TOKEN" --from-literal=pawmery_pet_cf_dns_token="$PAWMERY_PET_CF_DNS_TOKEN"
    echo "🔑 Secret created"
fi
