#!/usr/bin/env sh
set -e

gitleaks detect --source . --verbose --config gitleaks.toml \
  --report-path gitleaks-report.json --staged \
  || gitleaks detect --source . --verbose --config gitleaks.toml \
     --report-path gitleaks-report.json
