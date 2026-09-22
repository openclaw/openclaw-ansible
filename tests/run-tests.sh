#!/usr/bin/env bash
set -euo pipefail

DISTRO="${1:-ubuntu2404}"
IMAGE="openclaw-ansible-test:${DISTRO}"

echo "Building test image (${DISTRO})..."
docker build -t "$IMAGE" -f "tests/Dockerfile.${DISTRO}" .

echo "Running tests..."
docker run --rm "$IMAGE"

echo "Verifying a newer installed Node.js runtime is preserved..."
docker run --rm --entrypoint ansible-playbook "$IMAGE" tests/nodejs-upgrade.yml \
  -e nodejs_test_initial_series=26.x -e nodejs_test_expected_major=26
