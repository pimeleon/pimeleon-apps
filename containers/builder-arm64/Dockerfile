FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

ARG APT_CACHE_SERVER
ARG APT_CACHE_PORT=3142

# APT proxy (mirrors pi-router-build pattern exactly)
RUN if [ -n "${APT_CACHE_SERVER}" ]; then \
      printf 'Acquire::Retries "3";\nAcquire::http::Pipeline-Depth "0";\n' \
        > /etc/apt/apt.conf.d/80-retries && \
      printf 'Acquire::http::Proxy "http://%s:%s";\nAcquire::https::Proxy "DIRECT";\n' \
        "${APT_CACHE_SERVER}" "${APT_CACHE_PORT}" \
        > /etc/apt/apt.conf.d/01proxy; \
    fi

# Enable arm64 multiarch
RUN dpkg --add-architecture arm64

RUN apt-get update && apt-get install -yq --no-install-recommends \
    build-essential \
    crossbuild-essential-arm64 \
    ca-certificates \
    curl \
    file \
    git \
    pkg-config \
    python3 \
    autoconf \
    automake \
    libtool \
    # arm64 dev libraries for source builds
    libevent-dev:arm64 \
    libssl-dev:arm64 \
    zlib1g-dev:arm64 \
    libsystemd-dev:arm64 \
    libnl-3-dev:arm64 \
    libnl-genl-3-dev:arm64 \
    libpcap-dev:arm64 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Go toolchain for arm64 cross-compilation
COPY cache/tools/go*.tar.gz /tmp/go.tar.gz
RUN tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOARCH=arm64
ENV CGO_ENABLED=1
ENV CC=aarch64-linux-gnu-gcc

RUN mkdir -p /package /scripts /output

CMD ["bash"]
