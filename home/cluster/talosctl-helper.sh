#!/bin/bash

set -e

CLUSTER_NAME=nori-cloud
CONTROL_PLANE_IP=10.0.0.110
DISK_NAME=sda
WORKER_IP=()

# Infisical (source of truth for the live talosconfig)
INFISICAL_PROJECT_ID=8f0b1fbd-3bcf-4f49-bb35-93961d4229f7
INFISICAL_ENV=prod
TALOS_CONFIG_SECRET=talos-master-00-config

ACTION=""

usage() {
	echo "Usage: $0 --action <action>"
	echo ""
	echo "Actions:"
	echo "  get-disks    - Get installation disk info"
	echo "  gen-config   - Generate Talos configuration"
	echo "  apply-config - Apply configuration to nodes"
	echo "  set-endpoint - Set talosctl endpoint"
	echo "  bootstrap          - Bootstrap etcd"
	echo "  kubeconfig         - Get kubectl access"
	echo "  get-current-config - Fetch live talosconfig from Infisical into ~/.talos/config"
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

apply_control_plane_config() {
	echo "Applying configuration to control plane..."
	talosctl apply-config --insecure --nodes $CONTROL_PLANE_IP --file controlplane.yaml
}

apply_worker_config() {
	echo "Applying configuration to workers..."
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

get_current_config() {
	echo "Fetching talosconfig from Infisical (secret: $TALOS_CONFIG_SECRET)..."
	command -v infisical >/dev/null || { echo "Error: infisical CLI not found"; exit 1; }

	local work
	work=$(mktemp -d)
	trap 'rm -rf "$work"' RETURN

	(
		umask 077
		infisical secrets get "$TALOS_CONFIG_SECRET" \
			--projectId "$INFISICAL_PROJECT_ID" \
			--env "$INFISICAL_ENV" \
			--plain --silent > "$work/talosconfig"
	)

	if [[ ! -s "$work/talosconfig" ]]; then
		echo "Error: fetched talosconfig is empty"
		exit 1
	fi

	# Drop any existing context with the same name so merge doesn't create a
	# "<name>-1" duplicate on repeated runs (idempotent refresh).
	local ctx
	ctx=$(talosctl --talosconfig="$work/talosconfig" config info 2>/dev/null \
		| awk -F': *' '/Current context/{print $2}')
	if [[ -n "$ctx" ]]; then
		talosctl config remove "$ctx" --noconfirm >/dev/null 2>&1 || true
	fi

	echo "Merging into ~/.talos/config..."
	talosctl config merge "$work/talosconfig"
	talosctl config info
}

case $ACTION in
	get-disks)
		get_disks
		;;
	gen-config)
		gen_config
		;;
	apply-cp-config)
		apply_control_plane_config
		;;
	apply-worker-config)
		apply_worker_config
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
	get-current-config)
		get_current_config
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
