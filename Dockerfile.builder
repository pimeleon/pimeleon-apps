# Pimeleon Builder - Generalized Dockerfile
ARG TARGET_ARCH=armhf

FROM debian:12-slim AS base

ENV DEBIAN_FRONTEND=noninteractive

# Common Build Arguments
ARG APT_CACHE_SERVER=192.168.76.5
ARG APT_CACHE_PORT=3142

# Create required directories early while path is clean and ensure they are writable
RUN /bin/mkdir -p /package /scripts /output /build /logs && /bin/chmod 777 /package /scripts /output /build /logs

# Configure APT proxy if provided
RUN if [ -n "${APT_CACHE_SERVER}" ]; then \
    printf 'Acquire::Retries "3";\nAcquire::http::Pipeline-Depth "0";\n' \
    > /etc/apt/apt.conf.d/80-retries && \
    printf 'Acquire::https::Proxy "DIRECT";\n' > /etc/apt/apt.conf.d/01proxy; \
    fi
# Architecture-specific setup
FROM base AS arch-armhf
ENV DASH_ARCH=armhf
ENV COMPILER_PREFIX=arm-linux-gnueabihf-
ENV GOARCH=arm
ENV GOARM=7

FROM base AS arch-arm64
ENV DASH_ARCH=arm64
ENV COMPILER_PREFIX=aarch64-linux-gnu-
ENV GOARCH=arm64
ENV GOARM=

# Final stage selected by build argument
ARG TARGET_ARCH
FROM arch-${TARGET_ARCH} AS final

# Re-declare arguments needed in this stage
ARG GO_VERSION=1.24.0
ARG APT_CACHE_SERVER=192.168.76.5
ARG APT_CACHE_PORT=3142

# Enable multiarch
RUN dpkg --add-architecture ${DASH_ARCH}

# Configure APT proxy if provided
RUN if [ -n "${APT_CACHE_SERVER}" ]; then \
    printf 'Acquire::Retries "3";\nAcquire::http::Pipeline-Depth "0";\n' \
    > /etc/apt/apt.conf.d/80-retries && \
    printf 'Acquire::https::Proxy "DIRECT";\n' > /etc/apt/apt.conf.d/01proxy; \
    fi

# Install dependencies
RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    apt-get update && apt-get -qy upgrade && apt-get install -qy --no-install-recommends \
    cmake \
    ninja-build \
    build-essential \
    crossbuild-essential-${DASH_ARCH} \
    ca-certificates \
    coreutils \
    util-linux \
    xxd \
    libcap2-bin \
    curl \
    file \
    git \
    pkg-config \
    python3 \
    python3-jinja2 \
    autoconf \
    automake \
    libtool \
    sqlite3 \
    sudo \
    # Multi-arch development libraries
    libreadline-dev:${DASH_ARCH} \
    libidn2-dev:${DASH_ARCH} \
    libidn11-dev:${DASH_ARCH} \
    nettle-dev:${DASH_ARCH} \
    libgmp-dev:${DASH_ARCH} \
    libmbedtls-dev:${DASH_ARCH} \
    libunistring-dev:${DASH_ARCH} \
    libtinfo-dev:${DASH_ARCH} \
    libsqlite3-dev:${DASH_ARCH} \
    libevent-dev:${DASH_ARCH} \
    libssl-dev:${DASH_ARCH} \
    zlib1g-dev:${DASH_ARCH} \
    libsystemd-dev:${DASH_ARCH} \
    libnl-3-dev:${DASH_ARCH} \
    libnl-genl-3-dev:${DASH_ARCH} \
    libnl-route-3-dev:${DASH_ARCH} \
    libdbus-1-dev:${DASH_ARCH} \
    libpcre2-dev:${DASH_ARCH} \
    libzstd-dev:${DASH_ARCH} \
    libpcap-dev:${DASH_ARCH} \
    libcap-dev:${DASH_ARCH} \
    liblzma-dev:${DASH_ARCH} \
    > /dev/null 2>&1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Go toolchain — pre-fetched by update-tools.sh into cache/tools/ before docker build
COPY cache/tools/ /tmp/go-tools/
RUN tar -C /usr/local -xzf "/tmp/go-tools/go${GO_VERSION}.linux-amd64.tar.gz" \
    && rm -rf /tmp/go-tools

# Final environment variables
ENV PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV GOTOOLCHAIN=local
ENV CGO_ENABLED=1
ENV CC=${COMPILER_PREFIX}gcc
ENV PKG_CONFIG_PATH=/usr/lib/${COMPILER_PREFIX%-}/pkgconfig

CMD ["bash"]
