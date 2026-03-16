#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------- version ----------
SHORT_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
TIMESTAMP="$(date -u +%Y%m%d%H%M%S)"
VERSION="${SHORT_SHA}-${TIMESTAMP}"

# ---------- configurable env ----------
IMAGE_NAME="${IMAGE_NAME:-affine}"
BUILD_TYPE="${BUILD_TYPE:-canary}"
PLATFORM="${PLATFORM:-linux/amd64}"

# Registry: GHCR
GHCR_REGISTRY="${GHCR_REGISTRY:-ghcr.io}"
GHCR_REPO="${GHCR_REPO:-}"

# Registry: Alibaba Cloud ACR
ALIYUN_REGISTRY="${ALIYUN_REGISTRY:-}"
ALIYUN_REPO="${ALIYUN_REPO:-}"

# ---------- flags ----------
PUSH_GHCR=false
PUSH_ALIYUN=false
SKIP_BUILD=false
DOCKER_ONLY=true  # default: build everything inside Docker

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build an AFFiNE Docker image for Linux/amd64.
By default, everything is compiled inside Docker (no local Rust/Node needed).

Options:
  --push-ghcr       Push image to GitHub Container Registry
  --push-aliyun     Push image to Alibaba Cloud ACR
  --local-build     Build frontend/server locally, then package into Docker
                    (requires local yarn + Rust toolchain)
  --skip-build      Skip the compile steps, use existing artifacts
                    (only valid with --local-build)
  --version VER     Override the auto-generated version tag
  -h, --help        Show this help message

Environment variables:
  IMAGE_NAME         Base image name          (default: affine)
  BUILD_TYPE         Build type               (default: canary)
  PLATFORM           Docker platform          (default: linux/amd64)
  GHCR_REGISTRY      GHCR registry host       (default: ghcr.io)
  GHCR_REPO          GHCR repository path     (e.g. ohyee/affine)
  ALIYUN_REGISTRY    Alibaba ACR registry     (e.g. registry.cn-hangzhou.aliyuncs.com)
  ALIYUN_REPO        Alibaba ACR repo path    (e.g. myns/affine)

EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push-ghcr)    PUSH_GHCR=true; shift ;;
    --push-aliyun)  PUSH_ALIYUN=true; shift ;;
    --local-build)  DOCKER_ONLY=false; shift ;;
    --skip-build)   SKIP_BUILD=true; shift ;;
    --version)      VERSION="$2"; shift 2 ;;
    -h|--help)      usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
fail()  { echo -e "\033[1;31m[FAIL]\033[0m $*"; exit 1; }

cd "$REPO_ROOT"

info "Version: $VERSION"
info "Platform: $PLATFORM"

# ---------- collect tags ----------
TAGS=()
LOCAL_TAG="${IMAGE_NAME}:${VERSION}"
TAGS+=("-t" "$LOCAL_TAG")

if [[ "$PUSH_GHCR" == "true" ]]; then
  [[ -z "$GHCR_REPO" ]] && fail "GHCR_REPO is required when --push-ghcr is set"
  GHCR_TAG="${GHCR_REGISTRY}/${GHCR_REPO}:${VERSION}"
  GHCR_LATEST="${GHCR_REGISTRY}/${GHCR_REPO}:latest"
  TAGS+=("-t" "$GHCR_TAG" "-t" "$GHCR_LATEST")
fi

if [[ "$PUSH_ALIYUN" == "true" ]]; then
  [[ -z "$ALIYUN_REGISTRY" ]] && fail "ALIYUN_REGISTRY is required when --push-aliyun is set"
  [[ -z "$ALIYUN_REPO" ]] && fail "ALIYUN_REPO is required when --push-aliyun is set"
  ALIYUN_TAG="${ALIYUN_REGISTRY}/${ALIYUN_REPO}:${VERSION}"
  ALIYUN_LATEST="${ALIYUN_REGISTRY}/${ALIYUN_REPO}:latest"
  TAGS+=("-t" "$ALIYUN_TAG" "-t" "$ALIYUN_LATEST")
fi

PUSH_FLAG=""
if [[ "$PUSH_GHCR" == "true" || "$PUSH_ALIYUN" == "true" ]]; then
  PUSH_FLAG="--push"
fi

# ---------- build ----------
if [[ "$DOCKER_ONLY" == "true" ]]; then
  # All-in-one: compile everything inside Docker
  info "Building Docker image (all-in-one, compiling inside Docker) ..."
  docker buildx build \
    --platform "$PLATFORM" \
    --file .github/deployment/node/Dockerfile.all-in-one \
    --build-arg BUILD_TYPE="$BUILD_TYPE" \
    "${TAGS[@]}" \
    ${PUSH_FLAG} \
    --load \
    .

else
  # Local build: compile locally, then package
  if [[ "$SKIP_BUILD" == "false" ]]; then
    info "Installing dependencies ..."
    yarn install

    info "Building @affine/web ..."
    BUILD_TYPE="$BUILD_TYPE" yarn affine @affine/web build

    info "Building @affine/admin ..."
    BUILD_TYPE="$BUILD_TYPE" yarn affine @affine/admin build

    info "Building @affine/mobile ..."
    BUILD_TYPE="$BUILD_TYPE" yarn affine @affine/mobile build

    info "Building server-native (x86_64-unknown-linux-gnu) ..."
    yarn workspace @affine/server-native build --target x86_64-unknown-linux-gnu

    info "Creating placeholder .node files for non-x64 architectures ..."
    touch packages/backend/native/server-native.arm64.node
    touch packages/backend/native/server-native.armv7.node

    info "Building @affine/server ..."
    yarn workspace @affine/server build

    ok "All artifacts built successfully."
  fi

  info "Installing production dependencies ..."
  yarn workspaces focus @affine/server --production

  info "Generating Prisma client ..."
  yarn workspace @affine/server prisma generate

  info "Moving node_modules into server package ..."
  rm -rf packages/backend/server/node_modules
  mv node_modules packages/backend/server/

  info "Building Docker image (local artifacts) ..."
  docker buildx build \
    --platform "$PLATFORM" \
    --file .github/deployment/node/Dockerfile \
    "${TAGS[@]}" \
    ${PUSH_FLAG} \
    --load \
    .
fi

ok "Docker image built: $LOCAL_TAG"

if [[ "$PUSH_GHCR" == "true" ]]; then
  ok "Pushed to GHCR: $GHCR_TAG"
fi

if [[ "$PUSH_ALIYUN" == "true" ]]; then
  ok "Pushed to Alibaba ACR: $ALIYUN_TAG"
fi

echo ""
info "Done! Image version: $VERSION"
