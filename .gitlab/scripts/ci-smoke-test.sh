#!/usr/bin/env sh
set -e

apk add --no-cache bash curl

REGISTRY_IMAGE="${CI_REGISTRY_IMAGE:-gitlab.pirouter.dev:5005/pimeleon/pi-router-apps}/builder-${TARGET_ARCH}:latest"

if [ -n "${CI_JOB_TOKEN:-}" ]; then
  echo "${CI_JOB_TOKEN}" | docker login "${CI_REGISTRY:-gitlab.pirouter.dev:5005}" \
    -u gitlab-ci-token --password-stdin >/dev/null 2>&1
fi

docker pull "${REGISTRY_IMAGE}"
docker run --rm "${REGISTRY_IMAGE}" go version
