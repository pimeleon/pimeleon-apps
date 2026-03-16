FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# Create required directories early while path is clean and ensure they are writable
RUN /bin/mkdir -p /package /scripts /output /build /logs && /bin/chmod 777 /package /scripts /output /build /logs

ARG APT_CACHE_SERVER
ARG APT_CACHE_PORT=3142

# Configure APT proxy
RUN echo "Acquire::http::Proxy \"http://${APT_CACHE_SERVER}:${APT_CACHE_PORT}\";" > /etc/apt/apt.conf.d/01proxy && echo "Acquire::https::Proxy \"DIRECT\";" >> /etc/apt/apt.conf.d/01proxy && echo "Acquire::http::Pipeline-Depth \"0\";" >> /etc/apt/apt.conf.d/01proxy

# Enable armhf multiarch
RUN dpkg --add-architecture armhf

RUN apt-get update && apt-get dist-upgrade -yq && apt-get install -yq --no-install-recommends \
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
    xxd \
    libcap2-bin \
    libcap-dev:armhf \
    curl \
    file \
    git \
    pkg-config \
    python3 \
    python3-jinja2 \
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
    libnl-route-3-dev:armhf \
    libdbus-1-dev:armhf \
    libpcre2-dev:armhf \
    libzstd-dev:armhf \
    libpcap-dev:armhf \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Go toolchain for armhf cross-compilation
COPY cache/tools/go*.tar.gz /usr/local/go.tar.gz
RUN tar -C /usr/local -xzf /usr/local/go.tar.gz && rm /usr/local/go.tar.gz
ENV PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV GOTOOLCHAIN=local
ENV GOARCH=arm
ENV GOARM=7
ENV CGO_ENABLED=1
ENV CC=arm-linux-gnueabihf-gcc

CMD ["bash"]
