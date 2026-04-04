.PHONY: help build compile compile-all compile-tor compile-dns compile-hostapd compile-wpa_supplicant compile-privoxy compile-pihole clean lint factory-init refresh-tools tor dns dnscrypt-proxy hostapd wpa_supplicant privoxy pihole-ftl pihole pi-hole

# Use bash for all recipes and run in a single shell per target
SHELL := /bin/bash
.ONESHELL:

# Default settings
TARGET_ARCH ?= armhf
SOURCES ?= github
APT_PROXY ?=
QUIET ?= 0

# Load environment variables from .env if it exists
-include .env

# Extract Go version from env
GO_VERSION := $(BUILDER_GO_VERSION)

# Get the current directory for absolute paths in traps
PROJECT_ROOT = $(CURDIR)

# Export all variables to subshells
export TARGET_ARCH SOURCES APT_PROXY QUIET GITLAB_FETCH_TOKEN GO_VERSION

# Parse proxy variables for docker build
ifneq ($(APT_PROXY),)
    CACHE_SERVER = $(shell echo $(APT_PROXY) | cut -d: -f1)
    CACHE_PORT = $(shell echo $(APT_PROXY) | cut -s -d: -f2)
    PROXY_ARGS = --build-arg APT_CACHE_SERVER=$(CACHE_SERVER) --build-arg APT_CACHE_PORT=$(if $(CACHE_PORT),$(CACHE_PORT),3142)
endif

# Token and version for fetching tools from GitLab registry
DOCKER_BUILD_ARGS = --build-arg TARGET_ARCH=$(TARGET_ARCH) \
                    --build-arg GO_VERSION=$(GO_VERSION) \
                    $(if $(GITLAB_FETCH_TOKEN),--build-arg GITLAB_FETCH_TOKEN=$(GITLAB_FETCH_TOKEN)) \
                    $(PROXY_ARGS)

export PROXY_ARGS DOCKER_BUILD_ARGS

help:
	@echo "Pimeleon App Factory"
	@echo "====================="
	@echo "targets:"
	@echo "  make compile        - Compile all apps for $(TARGET_ARCH)"
	@echo "  make tor            - Compile Tor binary"
	@echo "  make dnscrypt-proxy - Compile DNSCrypt-Proxy binary"
	@echo "  make hostapd        - Compile Hostapd binary"
	@echo "  make wpa_supplicant - Compile Wpa_supplicant binary"
	@echo "  make privoxy        - Compile Privoxy binary"
	@echo "  make pihole-ftl     - Compile Pi-hole FTL binary"
	@echo "  make factory-init   - Prepare/Force-rebuild builder environment"
	@echo "  make refresh-tools  - Download/cache build tools locally"
	@echo "  make clean          - Clear local build artifacts"

build: compile
compile: compile-all

# Intuitive Aliases
tor: compile-tor
dns: compile-dns
dnscrypt-proxy: compile-dns
hostapd: compile-hostapd
wpa_supplicant: compile-wpa_supplicant
privoxy: compile-privoxy
pihole-ftl: compile-pihole
pihole: compile-pihole
pi-hole: compile-pihole

# Builder environment setup (ALWAYS rebuilt with --no-cache)
factory-init: refresh-tools
	@echo "Initializing pimeleon-factory-$(TARGET_ARCH) environment..."
	@echo "Build args: $(DOCKER_BUILD_ARGS)"
	@trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM
	docker build --no-cache $(DOCKER_BUILD_ARGS) -t pimeleon-builder-$(TARGET_ARCH):latest \
		-f Dockerfile.builder .

compile-tor:
	@echo "==> Building tor (latest) [Arch: $(TARGET_ARCH), Source: $(SOURCES)]"
	@trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM
	./scripts/build-package.sh tor

compile-dns:
	@echo "==> Building dnscrypt-proxy (latest) [Arch: $(TARGET_ARCH), Source: $(SOURCES)]"
	@trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM
	./scripts/build-package.sh dnscrypt-proxy

compile-hostapd:
	@echo "==> Building hostapd (latest) [Arch: $(TARGET_ARCH), Source: $(SOURCES)]"
	@trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM
	./scripts/build-package.sh hostapd

compile-wpa_supplicant:
	@echo "==> Building wpa_supplicant (latest) [Arch: $(TARGET_ARCH), Source: $(SOURCES)]"
	@trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM
	./scripts/build-package.sh wpa_supplicant

compile-privoxy:
	@echo "==> Building privoxy (latest) [Arch: $(TARGET_ARCH), Source: $(SOURCES)]"
	@trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM
	./scripts/build-package.sh privoxy

compile-pihole:
	@echo "==> Building pihole-ftl (latest) [Arch: $(TARGET_ARCH), Source: $(SOURCES)]"
	@trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM
	./scripts/build-package.sh pihole-FTL

compile-all: compile-tor compile-dns compile-hostapd compile-wpa_supplicant compile-privoxy compile-pihole

clean:
	rm -rf output/*.tar.gz output/*.sha256
	rm -rf build/

lint:
	./scripts/quality-benchmark.sh

# Download and cache required build tools
refresh-tools:
	@./scripts/update-tools.sh
