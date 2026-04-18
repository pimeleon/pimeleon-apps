#!/usr/bin/env sh
set -e

ARCH="${1:?Usage: trivy-scan.sh <arch>}"
IMAGE_NAME="${CI_REGISTRY_IMAGE}/builder-${ARCH}:latest"

trivy image --ignore-unfixed --scanners "${TRIVY_SCANNERS}" \
  --format json --output "trivy-builder-${ARCH}-report.json" "${IMAGE_NAME}"

trivy image --ignore-unfixed --scanners "${TRIVY_SCANNERS}" \
  --format table --exit-code 1 "${IMAGE_NAME}"
