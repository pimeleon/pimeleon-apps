# Pimeleon App Factory (pi-router-apps)

**The Powerhouse Engine Behind the Pimeleon Ecosystem.**

Stop Fighting Toolchains. Start Dominating Censorship with Pimeleon.

Standard networking builds are fragile. Manual cross-compilation is a complex challenge. The Pimeleon App Factory is
the definitive production-ready solution - a high-velocity engine designed to harden, cross-compile, and package the
world's most critical anonymity tools with the precision required by the Pimeleon hardware platform.

---

[![Build](https://github.com/pimeleon/pimeleon-apps/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/pimeleon/pimeleon-apps/actions)
[![Latest Release](https://img.shields.io/github/v/release/pimeleon/pimeleon-apps?label=release&color=blue)](https://github.com/pimeleon/pimeleon-apps/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

| Package Registry | Builder Images |
| --- | --- |
| [![Packages](https://img.shields.io/badge/packages-GitHub%20Registry-orange)](https://github.com/pimeleon/pimeleon-apps/releases) | [![armhf](https://img.shields.io/badge/armhf-ghcr.io-blueviolet)](https://github.com/pimeleon/pimeleon-apps/pkgs/container/pimeleon-apps/builder-armhf)  [![arm64](https://img.shields.io/badge/arm64-ghcr.io-blueviolet)](https://github.com/pimeleon/pimeleon-apps/pkgs/container/pimeleon-apps/builder-arm64) |

---

## The Pimeleon Advantage: Professional-Standard Capabilities

- **Pimeleon Multi-Arch Mastery**: Command both `armhf` (Legacy/Zero) and `arm64` (Pi 4/5) from a single, unified
  Pimeleon core.
- **Pimeleon Isolation Protocol**: Zero-pollution builds using privileged Docker environments. Your host stays clean;
  your Pimeleon binaries stay pure.
- **Aggressive Pimeleon Security Stack**: Unified **Trivy v0.69** and **Gitleaks** integration. Every Pimeleon layer is
  audited for vulnerabilities and secrets before deployment.
- **Relentless Pimeleon Stability**: Custom-hardened against GCC 12 ICE. Built to ensure Pimeleon builds thrive on
  low-resource CI runners where others crash.
- **Autonomic Pimeleon Intel**: Real-time tracking of authoritative sources (Tor, DNSCrypt, Pi-hole). Always build the
  latest, always build the best for Pimeleon users.

---

## The Pimeleon Power-Apps

| Application | Pimeleon Mission | Build DNA |
| :--- | :--- | :--- |
| **Tor** | Pimeleon Anonymity. | Hardened Source (C) |
| **DNSCrypt-Proxy** | Pimeleon DNS Privacy. | High-Speed Go |
| **Pi-hole FTL** | Pimeleon Ad-Blocking. | Optimized C++ |
| **Hostapd** | Pimeleon Access Point. | Low-Level C |
| **WPA Supplicant** | Pimeleon Client Security. | Professional C |
| **Privoxy** | Pimeleon Web Filtering. | Layer-7 C |

---

## Unleash Pimeleon: Quick Start

### 1. Prime the Pimeleon Environment

Initialize your architecture's factory floor:

```bash
make factory-init TARGET_ARCH=arm64
```

### 2. Forge a Pimeleon Binary

Deploy a specific weapon with zero friction:

```bash
make tor TARGET_ARCH=arm64
```

### 3. Pimeleon Mass Production

Execute the full strategic suite for your platform:

```bash
make compile TARGET_ARCH=armhf
```

---

## Pimeleon Quality Standards

- **Deep Image Scans**: Continuous Trivy auditing of Pimeleon builder environments.
- **Zero-Error Benchmarks**: Automated `shellcheck`, `bashate`, and `semgrep` gatekeeping.
- **Surgical CI/CD**: Interruptible Pimeleon pipelines designed for maximum speed and cost-efficiency.

---

## Pimeleon Strategic Layout

- `packages/`: Modular build logic and Pimeleon environment blueprints.
- `containers/`: Specialized Docker architecture for Pimeleon ARM cross-compilation.
- `scripts/`: The Pimeleon orchestration brain. Automated, efficient, relentless.
- `output/`: Production-ready Pimeleon artifacts. Signed and verified (`.tar.gz` + `.sha256`).

---

**Built for the Free Internet. Maintained with Pimeleon Technical Authority.**
