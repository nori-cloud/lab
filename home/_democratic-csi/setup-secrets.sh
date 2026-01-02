#!/bin/bash

set -e

NAMESPACE="democratic-csi"
SSH_USER="democratic-csi"

usage() {
    echo "Usage: $0 --api-key <key> --ssh-key <path> [options]"
    echo ""
    echo "Creates Kubernetes secrets containing Democratic-CSI driver configs"
    echo "for both iSCSI and NFS drivers."
    echo ""
    echo "Required:"
    echo "  --api-key        TrueNAS API key"
    echo "  --ssh-key        Path to SSH private key file"
    echo ""
    echo "Optional:"
    echo "  --host           TrueNAS host (default: 10.0.0.251)"
    echo "  --iscsi-only     Only configure iSCSI driver"
    echo "  --nfs-only       Only configure NFS driver"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "TrueNAS Setup Required:"
    echo "  1. Create API key in TrueNAS UI (top-right user menu → API Keys)"
    echo "  2. Create user '${SSH_USER}' with SSH public key"
    echo "  3. Create datasets for volumes and snapshots"
    echo "  4. Configure iSCSI portal and initiator groups"
    echo "  5. Configure NFS share permissions"
    exit 1
}

API_KEY=""
SSH_KEY_PATH=""
HOST="10.0.0.251"
ISCSI_ONLY=false
NFS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --iscsi-only)
            ISCSI_ONLY=true
            shift
            ;;
        --nfs-only)
            NFS_ONLY=true
            shift
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

if [[ -z "$API_KEY" || -z "$SSH_KEY_PATH" ]]; then
    echo "Error: --api-key and --ssh-key are required"
    usage
fi

if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "Error: SSH key file not found: $SSH_KEY_PATH"
    exit 1
fi

if [[ "$ISCSI_ONLY" == true && "$NFS_ONLY" == true ]]; then
    echo "Error: Cannot specify both --iscsi-only and --nfs-only"
    exit 1
fi

# Read SSH private key, preserving newlines
SSH_PRIVATE_KEY=$(cat "$SSH_KEY_PATH")

# =============================================================================
# iSCSI Driver Configuration
# =============================================================================
create_iscsi_secret() {
    echo "Creating iSCSI driver configuration..."

    ISCSI_CONFIG=$(cat <<EOF
driver: freenas-iscsi
instance_id:
httpConnection:
  protocol: http
  host: ${HOST}
  port: 80
  apiKey: ${API_KEY}
  allowInsecure: true
  apiVersion: 2
sshConnection:
  host: ${HOST}
  port: 22
  username: ${SSH_USER}
  privateKey: |
$(echo "$SSH_PRIVATE_KEY" | sed 's/^/    /')
zfs:
  cli:
    sudoEnabled: true
    paths:
      zfs: /usr/sbin/zfs
      zpool: /usr/sbin/zpool
  datasetParentName: volume-0/talos/iscsi/v
  detachedSnapshotsDatasetParentName: volume-0/talos/iscsi/s
  zvolCompression:
  zvolDedup:
  zvolEnableReservation: false
  zvolBlocksize:
iscsi:
  targetPortal: "${HOST}:3260"
  targetPortals: []
  interface:
  namePrefix: csi-
  nameSuffix: "-talos"
  targetGroups:
    - targetGroupPortalGroup: 1
      targetGroupInitiatorGroup: 1
      targetGroupAuthType: None
      targetGroupAuthGroup:
  extentInsecureTpc: true
  extentXenCompat: false
  extentDisablePhysicalBlocksize: true
  extentBlocksize: 512
  extentRpm: "SSD"
  extentAvailThreshold: 0
EOF
)

    kubectl create secret generic democratic-csi-iscsi-config \
        --namespace "$NAMESPACE" \
        --from-literal=driver-config-file.yaml="$ISCSI_CONFIG" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "  ✓ iSCSI secret created"
}

# =============================================================================
# NFS Driver Configuration
# =============================================================================
create_nfs_secret() {
    echo "Creating NFS driver configuration..."

    NFS_CONFIG=$(cat <<EOF
driver: freenas-nfs
instance_id:
httpConnection:
  protocol: http
  host: ${HOST}
  port: 80
  apiKey: ${API_KEY}
  allowInsecure: true
  apiVersion: 2
sshConnection:
  host: ${HOST}
  port: 22
  username: ${SSH_USER}
  privateKey: |
$(echo "$SSH_PRIVATE_KEY" | sed 's/^/    /')
zfs:
  cli:
    sudoEnabled: true
    paths:
      zfs: /usr/sbin/zfs
      zpool: /usr/sbin/zpool
  datasetParentName: volume-0/talos/nfs/v
  detachedSnapshotsDatasetParentName: volume-0/talos/nfs/s
  datasetEnableQuotas: true
  datasetEnableReservation: false
  datasetPermissionsMode: "0777"
  datasetPermissionsUser: 0
  datasetPermissionsGroup: 0
nfs:
  shareHost: "${HOST}"
  shareAlldirs: false
  shareAllowedHosts: []
  shareAllowedNetworks: []
  shareMaprootUser: root
  shareMaprootGroup: root
  shareMapallUser: ""
  shareMapallGroup: ""
EOF
)

    kubectl create secret generic democratic-csi-nfs-config \
        --namespace "$NAMESPACE" \
        --from-literal=driver-config-file.yaml="$NFS_CONFIG" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "  ✓ NFS secret created"
}

# =============================================================================
# Main
# =============================================================================

echo ""
echo "Democratic-CSI Secret Setup"
echo "==========================="
echo "Namespace: $NAMESPACE"
echo "TrueNAS Host: $HOST"
echo "SSH User: $SSH_USER"
echo ""

# Ensure namespace exists
kubectl get namespace "$NAMESPACE" &>/dev/null || {
    echo "Error: Namespace '$NAMESPACE' does not exist."
    echo "Run 'tofu apply' first to create the namespace."
    exit 1
}

if [[ "$NFS_ONLY" != true ]]; then
    create_iscsi_secret
fi

if [[ "$ISCSI_ONLY" != true ]]; then
    create_nfs_secret
fi

echo ""
echo "Done!"
echo ""
echo "Verify secrets:"
echo "  kubectl get secrets -n $NAMESPACE"
echo ""
echo "View iSCSI config:"
echo "  kubectl get secret democratic-csi-iscsi-config -n $NAMESPACE -o jsonpath='{.data.driver-config-file\.yaml}' | base64 -d"
echo ""
echo "View NFS config:"
echo "  kubectl get secret democratic-csi-nfs-config -n $NAMESPACE -o jsonpath='{.data.driver-config-file\.yaml}' | base64 -d"
