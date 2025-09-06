#! /bin/bash

set -e

PLAN_OUTPUT_DIR="./.plan"
TARGET_CLUSTER="module.cluster"
TARGET_NETWORKING="module.networking"
TARGET_BUTLER="module.butler"

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

echo "🏁 ACTION: $ACTION"

function apply() {
  local target=$1
  local plan_file=$PLAN_OUTPUT_DIR/$target.tfplan

  tofu plan -target=$target -out=$plan_file -compact-warnings > /dev/null

  if [ "$(tofu show $plan_file | grep -c "No changes.")" -gt 0 ]; then
    echo "✅ No changes needed for target: $target"
  else
    echo "🔨 Executing \"tofu apply $plan_file\""
    tofu apply $plan_file
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
    tofu apply $plan_file
    echo "✅ Destroyed infra"
  fi
}

echo "🏗️  Bootstraping infrastructure..."

case $ACTION in
  "apply")
    apply $TARGET_CLUSTER
    apply $TARGET_NETWORKING
    apply $TARGET_BUTLER
    ;;
  "plan")
    tofu plan -target=$TARGET_CLUSTER -compact-warnings
    ;;
  "destroy")
    destroy
    ;;
esac
