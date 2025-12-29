#!/bin/bash

set -e

NAMESPACE=networking
SECRET_NAME=cert-manager-creds
declare -A SECRET_DATA

# Parse command line arguments for custom key-value pairs
while [[ $# -gt 0 ]]; do
    case $1 in
        --key|-k)
            CURRENT_KEY="$2"
            shift 2
            ;;
        --value|-v)
            if [ -z "$CURRENT_KEY" ]; then
                echo "❌ Error: --value must follow --key"
                exit 1
            fi
            SECRET_DATA["$CURRENT_KEY"]="$2"
            CURRENT_KEY=""
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--key <key> --value <value>] ..."
            echo ""
            echo "Update cert-manager credentials secret (networking/cert-manager-creds)"
            echo ""
            echo "Options:"
            echo "  --key, -k      Secret key"
            echo "  --value, -v    Secret value (must follow --key)"
            echo "  --help, -h     Show this help"
            echo ""
            echo "Examples:"
            echo "  # Load from .env (default behavior)"
            echo "  $0"
            echo ""
            echo "  # Add custom key-value pair"
            echo "  $0 --key new_cf_token --value xyz123"
            echo ""
            echo "  # Add multiple keys"
            echo "  $0 -k token1 -v abc123 -k token2 -v def456"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# If no CLI args provided, load from .env (backward compatibility)
if [ ${#SECRET_DATA[@]} -eq 0 ]; then
    if [ -f .env ]; then
        echo "📃 Loading .env file..."
        source .env
    fi

    if [ -z "$NORRISWU_ME_CF_DNS_TOKEN" ] || [ -z "$PAWMERY_PET_CF_DNS_TOKEN" ]; then
        echo "❌ Need to set NORRISWU_ME_CF_DNS_TOKEN and PAWMERY_PET_CF_DNS_TOKEN in .env"
        echo "   Or use: $0 --key <key> --value <value>"
        exit 1
    fi

    SECRET_DATA["norriswu_me_cf_dns_token"]="$NORRISWU_ME_CF_DNS_TOKEN"
    SECRET_DATA["pawmery_pet_cf_dns_token"]="$PAWMERY_PET_CF_DNS_TOKEN"
fi

echo "🔧 Updating secret: $NAMESPACE/$SECRET_NAME"
echo "🔑 Keys to upsert: ${!SECRET_DATA[@]}"

# Build JSON for kubectl patch
JSON_DATA="{"
FIRST=true
for key in "${!SECRET_DATA[@]}"; do
    value="${SECRET_DATA[$key]}"
    encoded_value=$(echo -n "$value" | base64 -w0)

    if [ "$FIRST" = true ]; then
        JSON_DATA="$JSON_DATA\"$key\":\"$encoded_value\""
        FIRST=false
    else
        JSON_DATA="$JSON_DATA,\"$key\":\"$encoded_value\""
    fi
done
JSON_DATA="$JSON_DATA}"

echo "🔎 Checking if secret exists..."
if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" > /dev/null 2>&1; then
    echo "🔑 Found existing secret, upserting keys..."
    kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":$JSON_DATA}"
    echo "✅ Secret patched successfully"
else
    echo "🔑 Creating secret..."
    CMD="kubectl create secret generic \"$SECRET_NAME\" -n \"$NAMESPACE\""
    for key in "${!SECRET_DATA[@]}"; do
        value="${SECRET_DATA[$key]}"
        CMD="$CMD --from-literal=$key=\"$value\""
    done
    eval $CMD
    echo "✅ Secret created successfully"
fi

echo ""
echo "📋 Current secret keys:"
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]'

echo ""
echo "💡 Helpful commands:"
echo "   # View secret details"
echo "   kubectl get secret $SECRET_NAME -n $NAMESPACE -o yaml"
echo ""
echo "   # Decode a specific key"
echo "   kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.norriswu_me_cf_dns_token}' | base64 -d"
