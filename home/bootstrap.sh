#! /bin/bash

set -e

PLAN_OUTPUT_DIR="./.plan"
MODULE_CLUSTER="module.cluster"
MODULE_NETWORKING="module.networking"
MODULE_SYSTEM="module.system"

# Democratic-CSI secret configuration
CSI_NAMESPACE="democratic-csi"
CSI_SECRET_NAME="democratic-csi-driver-config"
CSI_SETUP_SCRIPT="./cluster/setup-democratic-csi-secret.sh"

if [ ! -d "$PLAN_OUTPUT_DIR" ]; then
  mkdir -p $PLAN_OUTPUT_DIR
fi

ACTION="apply"  # Default action

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -a|--action)
      ACTION="$2"
      # Validate action
      if [[ "$ACTION" != "plan" && "$ACTION" != "apply" && "$ACTION" != "destroy" ]]; then
        echo "Error: Invalid action '$ACTION'. Allowed actions: plan, apply, destroy"
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [-a|--action <action>]"
      echo "  -a, --action <action>  Action to perform: plan, apply, destroy (default: apply)"
      echo "  -h, --help            Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Check if Democratic-CSI secret exists
function check_csi_secret() {
  if kubectl get secret $CSI_SECRET_NAME -n $CSI_NAMESPACE &>/dev/null; then
    echo "✅ Democratic-CSI credentials secret exists"
    return 0
  else
    return 1
  fi
}

# Prompt user to create CSI secret
function setup_csi_secret() {
  echo ""
  echo "============================================================"
  echo "Democratic-CSI credentials secret not found!"
  echo "============================================================"
  echo ""
  echo "This secret is required for the storage driver to connect to TrueNAS."
  echo ""
  read -p "Do you want to create the secret now? (y/N) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter TrueNAS username [democratic-csi]: " CSI_USERNAME
    CSI_USERNAME=${CSI_USERNAME:-democratic-csi}

    read -s -p "Enter TrueNAS password: " CSI_PASSWORD
    echo ""

    if [[ -z "$CSI_PASSWORD" ]]; then
      echo "Error: Password cannot be empty"
      exit 1
    fi

    echo "Creating secret..."
    $CSI_SETUP_SCRIPT --username "$CSI_USERNAME" --password "$CSI_PASSWORD"
    echo ""
  else
    echo ""
    echo "To create the secret manually, run:"
    echo "  $CSI_SETUP_SCRIPT --username democratic-csi --password YOUR_PASSWORD"
    echo ""
    exit 1
  fi
}

echo "🏁 ACTION: $ACTION"

function apply() {
  local target=$1
  local plan_file=$PLAN_OUTPUT_DIR/$target.tfplan

  tofu plan -target=$target -out=$plan_file -compact-warnings > /dev/null

  if [ "$(tofu show $plan_file | grep -c "No changes.")" -gt 0 ]; then
    echo "✅ No changes needed for target: $target"
  else
    echo "🔨 Executing \"tofu apply $plan_file\""
    tofu apply $plan_file -compact-warnings
    echo "✅ Applied target: $target"
  fi
}

function destroy() {
  local plan_file=$PLAN_OUTPUT_DIR/destroy.tfplan

  tofu plan -destroy -out=$plan_file > /dev/null

  if [ "$(tofu show $plan_file | grep -c "No changes.")" -gt 0 ]; then
    echo "❓ Nothing to destroy"
  else
    echo "🔨 Executing \"tofu apply $plan_file\""
    tofu apply $plan_file -compact-warnings
    echo "✅ Destroyed infra"
  fi
}

echo "🏗️  Bootstraping infrastructure..."

case $ACTION in
  "apply")
    # Check for CSI secret before applying cluster module
    if ! check_csi_secret; then
      setup_csi_secret
    fi
    apply $MODULE_CLUSTER
    apply $MODULE_NETWORKING
    ;;
  "plan")
    echo "⚠️  Plan action will only plan for \"$MODULE_CLUSTER\" module"
    tofu plan -target=$MODULE_CLUSTER -compact-warnings
    ;;
  "destroy")
    destroy
    ;;
esac
