#!/usr/bin/env bash
#
# Build GPT Researcher from source and publish it for the local kind cluster.
#
# Image: Dockerfile.fullstack — UI + API + nginx in ONE container, port 3000
# (nginx serves the Next.js UI and proxies /outputs /reports /ws to the
# FastAPI backend on :8000).
#
# Default:  push to the internal registry (kind-registry.internal) — nodes
#           pull from it directly (containerd certs.d wired by
#           kind/scripts/50-registry.sh).
#   --load: side-load into the kind nodes instead (no registry needed;
#           deployment must use a matching :local tag with IfNotPresent).
#
# Progress goes to stderr; the FINAL LINE on stdout is the image ref, so
# callers can do:  IMAGE="$(bash cluster/push-image.sh)"
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REG_HOST="${REG_HOST:-kind-registry.internal}"
IMAGE_TAG="${IMAGE_TAG:-local}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kagent}"
MODE="registry"
[[ "${1:-}" == "--load" ]] && MODE="load"

RT="${CONTAINER_RUNTIME:-docker}"
command -v "$RT" >/dev/null 2>&1 || { echo "container runtime '$RT' not found" >&2; exit 1; }
[[ -f "$REPO_DIR/Dockerfile.fullstack" ]] || { echo "Dockerfile.fullstack missing in $REPO_DIR" >&2; exit 1; }

IMAGE="gpt-researcher:${IMAGE_TAG}"

echo "==> Building ${IMAGE} from source (${REPO_DIR}) — first build is slow (browsers + node_modules + pip)..." >&2
"$RT" build -f "$REPO_DIR/Dockerfile.fullstack" -t "$IMAGE" "$REPO_DIR" >&2

if [[ "$MODE" == "load" ]]; then
  command -v kind >/dev/null 2>&1 || { echo "kind not found" >&2; exit 1; }
  echo "==> Side-loading ${IMAGE} into kind cluster '${KIND_CLUSTER_NAME}'..." >&2
  kind load docker-image "$IMAGE" --name "$KIND_CLUSTER_NAME" >&2
  echo "$IMAGE"
else
  REMOTE="${REG_HOST}/gpt-researcher:${IMAGE_TAG}"
  echo "==> Tagging + pushing to internal registry: ${REMOTE}..." >&2
  "$RT" tag "$IMAGE" "$REMOTE" >&2
  "$RT" push "$REMOTE" >&2
  echo "$REMOTE"
fi
