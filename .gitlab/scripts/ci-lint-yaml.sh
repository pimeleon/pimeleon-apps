#!/usr/bin/env sh
set -e

apk add --no-cache yamllint
yamllint -c .yamllint .
