#! /bin/bash

set -e

PLAN_OUTPUT_DIR="./.plan"
TARGET_CLUSTER="module.cluster"
TARGET_NETWORKING="module.networking"
TARGET_BUTLER="module.butler"

if [ ! -d "$PLAN_OUTPUT_DIR" ]; then
  mkdir -p $PLAN_OUTPUT_DIR
fi

IS_APPLYING=
for arg in "$@"; do
  if [ "$arg" = "-a" ] || [ "$arg" = "--apply" ]; then
    echo "🏁 IS_APPLYING: true"
    IS_APPLYING=true
    break
  fi
done

function apply() {
  local target=$1
  local plan_file=$PLAN_OUTPUT_DIR/$target.tfplan

  tofu plan -target=$target -out=$plan_file > /dev/null

  if [ "$(tofu show $plan_file | grep -c "No changes.")" -gt 0 ]; then
    echo "✅ No changes needed for target: $target"
  else
    if [ "$IS_APPLYING" = true ]; then
      echo "🔨 Executing \"tofu apply $PLAN_OUTPUT_DIR/$target.tfplan\""
      tofu apply $PLAN_OUTPUT_DIR/$target.tfplan
      echo "✅ Applied target: $target"
    else
      echo "🔨 Would have applied following changes for target: $target"
      tofu show $plan_file
    fi
  fi
}

echo "🏗️  Bootstraping infrastructure..."

apply $TARGET_CLUSTER
apply $TARGET_NETWORKING
apply $TARGET_BUTLER
