#!/bin/bash

set -e

NAMESPACE="democratic-csi"
SECRET_NAME="democratic-csi-driver-config"

usage() {
    echo "Usage: $0 --username <username> --password <password>"
    echo ""
    echo "Creates a Kubernetes secret containing the Democratic-CSI driver config."
    echo "This secret is referenced by the Helm chart to connect to TrueNAS."
    echo ""
    echo "Options:"
    echo "  --username    TrueNAS API username (required)"
    echo "  --password    TrueNAS API password (required)"
    echo "  --host        TrueNAS host (default: 10.0.0.251)"
    echo "  -h, --help    Show this help message"
    exit 1
}

USERNAME=""
PASSWORD=""
HOST="10.0.0.251"

while [[ $# -gt 0 ]]; do
    case $1 in
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
    echo "Error: --username and --password are required"
    usage
fi

# Create the driver config YAML
DRIVER_CONFIG=$(cat <<EOF
driver: freenas-iscsi
instance_id:
httpConnection:
    protocol: http
    host: ${HOST}
    port: 80
    username: ${USERNAME}
    password: ${PASSWORD}
    allowInsecure: true
sshConnection:
    host: ${HOST}
    port: 22
    username: ${USERNAME}
    password: ${PASSWORD}
zfs:
    datasetParentName: volume-0/talos/iscsi/v
    detachedSnapshotsDatasetParentName: volume-0/talos/iscsi/s
    zvolCompression:
    zvolDedup:
    zvolEnableReservation: false
    zvolBlocksize:
iscsi:
    targetPortal: '${HOST}:3260'
    targetPortals: []
    interface:
    namePrefix: csi-
    nameSuffix: '-clustera'
    targetGroups:
        - targetGroupPortalGroup: 8
          targetGroupInitiatorGroup: 14
          targetGroupAuthType: None
          targetGroupAuthGroup:
    extentInsecureTpc: true
    extentXenCompat: false
    extentDisablePhysicalBlocksize: true
    extentBlocksize: 512
    extentRpm: ''
    extentAvailThreshold: 0
EOF
)

echo "Creating namespace $NAMESPACE if not exists..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "Creating secret $SECRET_NAME..."
kubectl create secret generic $SECRET_NAME \
    --namespace $NAMESPACE \
    --from-literal=driver-config-file.yaml="$DRIVER_CONFIG" \
    --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Done! Secret created in namespace $NAMESPACE"
echo ""
echo "Verify with:"
echo "  kubectl get secret $SECRET_NAME -n $NAMESPACE"
echo ""
echo "View config (base64 decoded):"
echo "  kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.driver-config-file\.yaml}' | base64 -d"
