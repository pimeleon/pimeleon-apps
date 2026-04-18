#!/usr/bin/env sh
set -e

apk add --no-cache shellcheck jq python3 py3-pip bash
python3 -m venv .venv && . .venv/bin/activate
pip install --no-cache-dir semgrep
./scripts/quality-benchmark.sh
