.PHONY: help build build-tor build-dnscrypt build-all clean lint build-builder

# Default settings
TARGET_ARCH ?= armhf
SOURCES ?= github
APT_PROXY ?=

# Get the current directory for absolute paths in traps
PROJECT_ROOT = $(CURDIR)

# Parse proxy variables for docker build
ifneq ($(APT_PROXY),)
    CACHE_SERVER = $(shell echo $(APT_PROXY) | cut -d: -f1)
    CACHE_PORT = $(shell echo $(APT_PROXY) | cut -s -d: -f2)
    PROXY_ARGS = --build-arg APT_CACHE_SERVER=$(CACHE_SERVER) --build-arg APT_CACHE_PORT=$(if $(CACHE_PORT),$(CACHE_PORT),3142)
endif

help:
	@echo "Pimeleon App Factory"
	@echo "====================="
	@echo "targets:"
	@echo "  make build          - Build all apps for $(TARGET_ARCH)"
	@echo "  make build-tor      - Build Tor binary"
	@echo "  make build-dnscrypt - Build DNSCrypt-Proxy binary"
	@echo "  make build-builder  - Forcibly rebuild builder image"
	@echo "  make clean          - Clear local build artifacts"

build: build-all

# Builder image is ALWAYS rebuilt with --no-cache to ensure fresh environment/proxy
# Wrapped in a robust trap to ensure graceful termination
build-builder:
	@echo "Building pimeleon-builder-$(TARGET_ARCH) image (forced rebuild)..."
	@/bin/bash -c 'trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM; \
		docker build --no-cache $(PROXY_ARGS) -t pimeleon-builder-$(TARGET_ARCH):latest \
			-f containers/builder-$(TARGET_ARCH)/Dockerfile .'

build-tor: build-builder
	@/bin/bash -c 'trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM; \
		TARGET_ARCH=$(TARGET_ARCH) SOURCES=$(SOURCES) APT_PROXY=$(APT_PROXY) ./scripts/build-package.sh tor'

build-dnscrypt: build-builder
	@/bin/bash -c 'trap "$(PROJECT_ROOT)/scripts/clean-docker.sh --clean-mounts; exit 1" INT TERM; \
		TARGET_ARCH=$(TARGET_ARCH) SOURCES=$(SOURCES) APT_PROXY=$(APT_PROXY) ./scripts/build-package.sh dnscrypt-proxy'

build-all: build-tor build-dnscrypt

clean:
	rm -rf output/*.tar.gz output/*.sha256

lint:
	./scripts/quality-benchmark.sh
