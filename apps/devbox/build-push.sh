#!/bin/bash

set -euo pipefail

# ---- Edit these to change where the image is published ----------------------
REGISTRY="ghcr.io"
IMAGE_NAME="nori-cloud/devbox"
DEFAULT_TAG="0.1.0"
PLATFORM="linux/amd64" # Talos node arch
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${REGISTRY}/${IMAGE_NAME}"

usage() {
    echo "Usage: $0 [tag] [--no-push] [--platform <p>]"
    echo ""
    echo "Builds and pushes the devbox image."
    echo ""
    echo "Arguments:"
    echo "  tag              Image tag to build (default: ${DEFAULT_TAG})"
    echo ""
    echo "Options:"
    echo "  --no-push        Build only, do not push to the registry"
    echo "  --platform <p>   Target platform (default: ${PLATFORM})"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                       # build & push ${IMAGE}:${DEFAULT_TAG}"
    echo "  $0 0.2.0                 # build & push ${IMAGE}:0.2.0"
    echo "  $0 dev --no-push         # build ${IMAGE}:dev locally only"
}

TAG="${DEFAULT_TAG}"
PUSH=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --no-push) PUSH=false; shift ;;
        --platform) PLATFORM="$2"; shift 2 ;;
        -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        *) TAG="$1"; shift ;;
    esac
done

REF="${IMAGE}:${TAG}"

echo ">> Building ${REF} (${PLATFORM})"
docker build --platform "${PLATFORM}" -t "${REF}" "${SCRIPT_DIR}"

if [[ "${PUSH}" == true ]]; then
    echo ">> Pushing ${REF}"
    docker push "${REF}"
    echo ">> Done. Update the image tag in apps/devbox/deployment.yaml to: ${REF}"
else
    echo ">> Built ${REF} locally (push skipped)."
fi
