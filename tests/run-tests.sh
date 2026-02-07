#!/usr/bin/env bash
set -euo pipefail

DISTRO="${1:-ubuntu2404}"
IMAGE="openclaw-ansible-test:${DISTRO}"

echo "Building test image (${DISTRO})..."
docker build -t "$IMAGE" -f "tests/Dockerfile.${DISTRO}" .

echo "Running tests..."
docker run --rm "$IMAGE"
