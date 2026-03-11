FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# Create required directories early while path is clean
RUN /bin/mkdir -p /package /scripts /output

ARG APT_CACHE_SERVER
ARG APT_CACHE_PORT=3142

# Configure APT proxy
RUN echo "Acquire::http::Proxy \"http://${APT_CACHE_SERVER}:${APT_CACHE_PORT}\";" > /etc/apt/apt.conf.d/01proxy && echo "Acquire::https::Proxy \"DIRECT\";" >> /etc/apt/apt.conf.d/01proxy && echo "Acquire::http::Pipeline-Depth \"0\";" >> /etc/apt/apt.conf.d/01proxy

# Enable armhf multiarch
RUN dpkg --add-architecture armhf

RUN apt-get update && apt-get install -yq --no-install-recommends \
    cmake \
    ninja-build \
    libreadline-dev:armhf \
    libidn2-dev:armhf \
    nettle-dev:armhf \
    libgmp-dev:armhf \
    libmbedtls-dev:armhf \
    libunistring-dev:armhf \
    libtinfo-dev:armhf \
    libsqlite3-dev:armhf \
    sqlite3 \
    build-essential \
    crossbuild-essential-armhf \
    ca-certificates \
    coreutils \
    util-linux \
    libcap2-bin \
    libcap-dev:armhf \
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

# Go toolchain for armhf cross-compilation
COPY cache/tools/go*.tar.gz /tmp/go.tar.gz
RUN tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV GOARCH=arm
ENV GOARM=7
ENV CGO_ENABLED=1
ENV CC=arm-linux-gnueabihf-gcc

CMD ["bash"]
