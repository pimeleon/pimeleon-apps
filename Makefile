.PHONY: help build build-tor build-dnscrypt build-all clean lint

# Default settings
TARGET_PLATFORM ?= rpi3-bookworm
SOURCES ?= github
APT_PROXY ?=

# Derive architecture from platform
ifeq ($(findstring rpi4,$(TARGET_PLATFORM)),rpi4)
    TARGET_ARCH = arm64
else
    TARGET_ARCH = armhf
endif

help:
	@echo "Pimeleon App Factory"
	@echo "====================="
	@echo "targets:"
	@echo "  make build          - Build all apps for $(TARGET_PLATFORM) ($(TARGET_ARCH))"
	@echo "  make build-tor      - Build Tor binary"
	@echo "  make build-dnscrypt - Build DNSCrypt-Proxy binary"
	@echo "  make clean          - Clear local build artifacts"

build: build-all

build-tor:
	@TARGET_ARCH=$(TARGET_ARCH) SOURCES=$(SOURCES) APT_PROXY=$(APT_PROXY) ./scripts/build-package.sh tor

build-dnscrypt:
	@TARGET_ARCH=$(TARGET_ARCH) SOURCES=$(SOURCES) APT_PROXY=$(APT_PROXY) ./scripts/build-package.sh dnscrypt-proxy

build-all: build-tor build-dnscrypt

clean:
	rm -rf output/*.tar.gz output/*.sha256

lint:
	./scripts/quality-benchmark.sh
