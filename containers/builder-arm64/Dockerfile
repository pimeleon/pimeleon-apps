FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# Create required directories early while path is clean
RUN /bin/mkdir -p /package /scripts /output

ARG APT_CACHE_SERVER
ARG APT_CACHE_PORT=3142

# Configure APT proxy
RUN echo "Acquire::http::Proxy \"http://${APT_CACHE_SERVER}:${APT_CACHE_PORT}\";" > /etc/apt/apt.conf.d/01proxy && echo "Acquire::https::Proxy \"DIRECT\";" >> /etc/apt/apt.conf.d/01proxy && echo "Acquire::http::Pipeline-Depth \"0\";" >> /etc/apt/apt.conf.d/01proxy

# Enable arm64 multiarch
RUN dpkg --add-architecture arm64

RUN apt-get update && apt-get install -yq --no-install-recommends \
    cmake \
    ninja-build \
    libreadline-dev:arm64 \
    libidn2-dev:arm64 \
    nettle-dev:arm64 \
    libgmp-dev:arm64 \
    libmbedtls-dev:arm64 \
    libunistring-dev:arm64 \
    libtinfo-dev:arm64 \
    libsqlite3-dev:arm64 \
    sqlite3 \
    build-essential \
    crossbuild-essential-arm64 \
    ca-certificates \
    coreutils \
    util-linux \
    libcap2-bin \
    libcap-dev:arm64 \
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
ENV PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV GOARCH=arm64
ENV CGO_ENABLED=1
ENV CC=aarch64-linux-gnu-gcc

CMD ["bash"]
