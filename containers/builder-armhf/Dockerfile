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

# Enable armhf multiarch
RUN dpkg --add-architecture armhf

RUN apt-get update && apt-get install -yq --no-install-recommends \
    build-essential \
    crossbuild-essential-armhf \
    ca-certificates \
    curl \
    file \
    git \
    pkg-config \
    python3 \
    autoconf \
    automake \
    libtool \
    # armhf dev libraries for source builds
    libevent-dev:armhf \
    libssl-dev:armhf \
    zlib1g-dev:armhf \
    libsystemd-dev:armhf \
    libnl-3-dev:armhf \
    libnl-genl-3-dev:armhf \
    libpcap-dev:armhf \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Go toolchain for armhf cross-compilation (dnscrypt-proxy is written in Go)
RUN curl -fsSL https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | tar xz -C /usr/local
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOARCH=arm
ENV GOARM=7
ENV CGO_ENABLED=1
ENV CC=arm-linux-gnueabihf-gcc

RUN mkdir -p /package /scripts /output

CMD ["/scripts/build-package.sh"]
