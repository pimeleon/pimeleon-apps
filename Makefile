.PHONY: help containers containers-armhf containers-arm64 \
        build build-all shell versions packages clean clean-output clean-containers lint

REPO_ROOT := $(shell pwd)

# Defaults (override on command line: make build PKG=tor ARCH=arm64)
PKG  ?=
ARCH ?= armhf

IMAGE_ARMHF := pi-router-apps/builder-armhf:local
IMAGE_ARM64 := pi-router-apps/builder-arm64:local

# ── Help ──────────────────────────────────────────────────────────────────────

help:
	@echo "pi-router-apps — local build management"
	@echo ""
	@echo "Container targets:"
	@echo "  make containers              Build both builder containers"
	@echo "  make containers-armhf        Build armhf builder only"
	@echo "  make containers-arm64        Build arm64 builder only"
	@echo ""
	@echo "Build targets:"
	@echo "  make build PKG=<pkg> [ARCH=armhf|arm64]   Build one package"
	@echo "  make build-all                             Build all packages for all arches"
	@echo ""
	@echo "Debug:"
	@echo "  make shell PKG=<pkg> [ARCH=armhf|arm64]   Open shell in builder container"
	@echo ""
	@echo "Info:"
	@echo "  make versions                Show current tracked versions"
	@echo "  make packages                List available packages"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean                   Remove output/ and dangling containers"
	@echo "  make clean-containers        Remove local builder images"
	@echo ""
	@echo "Lint:"
	@echo "  make lint                    Run shellcheck on all scripts"
	@echo ""
	@echo "Examples:"
	@echo "  make build PKG=dnscrypt-proxy"
	@echo "  make build PKG=tor ARCH=arm64"
	@echo "  make shell PKG=tor ARCH=armhf"
	@echo "  make build-all"

# ── Container builds ──────────────────────────────────────────────────────────

containers: containers-armhf containers-arm64

containers-armhf:
	@bash local-build.sh armhf

containers-arm64:
	@bash local-build.sh arm64

containers-no-cache:
	@bash local-build.sh all --no-cache

# ── Package builds ────────────────────────────────────────────────────────────

build:
	@[ -n "$(PKG)" ] || (echo "Error: PKG is required. Usage: make build PKG=<package>"; exit 1)
	@bash local-run.sh "$(PKG)" "$(ARCH)"

build-all:
	@echo "Building all packages for armhf and arm64..."
	@for pkg in packages/*/; do \
		name=$$(basename "$$pkg"); \
		for arch in armhf arm64; do \
			version_file="versions/$${name}-$${arch}.version"; \
			[ -f "$$version_file" ] || continue; \
			echo ""; \
			echo "==> $${name} ($${arch})"; \
			bash local-run.sh "$$name" "$$arch" || exit 1; \
		done; \
	done
	@echo ""
	@echo "All packages built. Output in output/"

# ── Debug shell ───────────────────────────────────────────────────────────────

shell:
	@[ -n "$(PKG)" ] || (echo "Error: PKG is required. Usage: make shell PKG=<package>"; exit 1)
	@bash local-run.sh "$(PKG)" "$(ARCH)" --shell

# ── Info ──────────────────────────────────────────────────────────────────────

versions:
	@echo "Current tracked versions:"
	@echo "========================="
	@for f in versions/*.version; do \
		[ -f "$$f" ] || continue; \
		name=$$(basename "$$f" .version); \
		printf "  %-35s %s\n" "$$name" "$$(cat $$f)"; \
	done

packages:
	@echo "Available packages:"
	@echo "==================="
	@for pkg in packages/*/; do \
		name=$$(basename "$$pkg"); \
		type=$$(grep '^BUILD_TYPE' "$$pkg/package.env" 2>/dev/null | cut -d= -f2 | tr -d '"'); \
		arches=$$(grep '^SUPPORTED_ARCHES' "$$pkg/package.env" 2>/dev/null | cut -d= -f2 | tr -d '"'); \
		printf "  %-20s type=%-8s arches=%s\n" "$$name" "$$type" "$$arches"; \
	done

# ── Cleanup ───────────────────────────────────────────────────────────────────

clean: clean-output
	@docker container prune -f 2>/dev/null || true
	@echo "Cleaned"

clean-output:
	rm -rf output/
	@echo "Removed output/"

clean-containers:
	docker rmi $(IMAGE_ARMHF) $(IMAGE_ARM64) 2>/dev/null || true
	@echo "Removed local builder images"

# ── Lint ──────────────────────────────────────────────────────────────────────

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		find scripts packages -name "*.sh" -exec shellcheck --severity=warning {} +; \
		shellcheck local-run.sh local-build.sh; \
		echo "shellcheck passed"; \
	else \
		docker run --rm -v "$(REPO_ROOT):/src" koalaman/shellcheck-alpine:stable \
			sh -c 'find /src/scripts /src/packages -name "*.sh" -exec shellcheck {} + && shellcheck /src/local-run.sh /src/local-build.sh'; \
	fi
