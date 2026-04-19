#!/bin/bash
# Mock curl: returns the actual hostapd directory listing we just downloaded
if [[ "$*" == *"w1.fi/releases/"* ]]; then
    cat tests/data/hostapd_releases.html
else
    /usr/bin/curl "$@"
fi
