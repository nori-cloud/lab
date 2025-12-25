#!/bin/bash

set -e

CLUSTER_NAME=nori-cloud
CONTROL_PLANE_IP=10.0.0.110
DISK_NAME=sda
WORKER_IP=("10.0.0.111" "10.0.0.112" "10.0.0.113")

ACTION=""

usage() {
    echo "Usage: $0 --action <action>"
    echo ""
    echo "Actions:"
    echo "  get-disks    - Get installation disk info"
    echo "  gen-config   - Generate Talos configuration"
    echo "  apply-config - Apply configuration to nodes"
    echo "  set-endpoint - Set talosctl endpoint"
    echo "  bootstrap    - Bootstrap etcd"
    echo "  kubeconfig   - Get kubectl access"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --action)
            ACTION="$2"
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

if [[ -z "$ACTION" ]]; then
    echo "Error: --action is required"
    usage
fi

get_disks() {
    echo "Getting installation disks..."
    talosctl get disks --insecure --nodes $CONTROL_PLANE_IP
}

gen_config() {
    echo "Generating Talos configuration..."
    talosctl gen config $CLUSTER_NAME https://$CONTROL_PLANE_IP:6443 --install-disk /dev/$DISK_NAME
}

apply_config() {
    echo "Applying configuration to control plane..."
    talosctl apply-config --insecure --nodes $CONTROL_PLANE_IP --file controlplane.yaml

    for ip in "${WORKER_IP[@]}"; do
        echo "Applying config to worker node: $ip"
        talosctl apply-config --insecure --nodes "$ip" --file worker.yaml
    done
}

set_endpoint() {
    echo "Setting talosctl endpoint..."
    talosctl --talosconfig=./talosconfig config endpoints $CONTROL_PLANE_IP
}

bootstrap_etcd() {
    echo "Bootstrapping etcd..."
    talosctl bootstrap --nodes $CONTROL_PLANE_IP --talosconfig=./talosconfig
}

get_kubeconfig() {
    echo "Getting kubectl access..."
    talosctl kubeconfig --nodes $CONTROL_PLANE_IP --talosconfig=./talosconfig
}

get_health() {
    echo "Getting cluster health..."
    talosctl --nodes $CONTROL_PLANE_IP --talosconfig=./talosconfig health
}

case $ACTION in
    get-disks)
        get_disks
        ;;
    gen-config)
        gen_config
        ;;
    apply-config)
        apply_config
        ;;
    set-endpoint)
        set_endpoint
        ;;
    bootstrap)
        bootstrap_etcd
        ;;
    kubeconfig)
        get_kubeconfig
        ;;
    health)
        get_health
        ;;
    *)
        echo "Unknown action: $ACTION"
        usage
        ;;
esac

echo "Done!"
