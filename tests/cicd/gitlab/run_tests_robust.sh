#!/bin/bash
set -euo pipefail

# 1. Probe network connectivity first, respecting potential system proxy environment
# If APT_PROXY is set, use it; otherwise, rely on system standard http_proxy
echo "Probing connectivity..."
if ! curl -Is --max-time 5 http://google.com > /dev/null 2>&1; then
    echo "[WARN] Direct internet access unavailable, assuming local/restricted network."
fi

# 2. Setup the environment with minimal overhead
# If APT_PROXY is explicitly provided, we configure it to ensure local build consistency
if [[ -n "" ]]; then
    echo "Configuring APT proxy: ${APT_PROXY}"
    export_proxy_cmd="echo 'Acquire::http::Proxy \"http:///\";' > /etc/apt/apt.conf.d/01proxy"
else
    echo "No APT proxy configured, running direct."
    export_proxy_cmd="rm -f /etc/apt/apt.conf.d/01proxy"
fi

# 3. Execute inside container
docker run --rm   -v "/home/takeshi/pi-router/pi-router-apps:/app"   -w /app   -e APT_PROXY=""   registry.gitlab.com/juhani/go-semrel-gitlab:v0.21.1   /bin/sh -c "

    # Only update if necessary to save time
    if [ ! -f /var/lib/apt/lists/lock ]; then
        apt-get update -q || true
    fi
    # Use existing bash/git/jq if already present in cached layers, else install
    if ! command -v git >/dev/null 2>&1; then
        apt-get install -qy git jq
    fi
    ./tests/cicd/gitlab/test_suite.sh
"
