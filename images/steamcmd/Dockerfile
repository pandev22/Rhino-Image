# syntax=docker/dockerfile:1.7
# ==============================================================================
# Rhino Panel - Official SteamCMD Container Image
# Minimal Debian 13 (Trixie) Slim + Multi-Arch i386 Glibc Runtime
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build static musl rhino-entrypoint binary (PID 1)
# ------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM rust:alpine AS entrypoint-builder
WORKDIR /build

RUN apk add --no-cache musl-dev

COPY entrypoint/ ./
RUN cargo build --release && \
    strip target/release/rhino-entrypoint

# ------------------------------------------------------------------------------
# Stage 2: Minimal SteamCMD Runtime
# ------------------------------------------------------------------------------
FROM debian:trixie-slim AS runtime

ARG TARGETARCH

LABEL org.opencontainers.image.title="Rhino Game Server - SteamCMD" \
      org.opencontainers.image.description="Minimal SteamCMD runtime on Debian 13 Trixie Slim with multi-arch 32-bit glibc" \
      org.opencontainers.image.vendor="Rhino Panel" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/pandev22/Rhino-Image"

ENV DEBIAN_FRONTEND=noninteractive \
    USER=rhino \
    HOME=/home/container \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    STEAM_DIR=/usr/local/steamcmd

# Install multiarch 32-bit glibc and required runtime dependencies
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        dpkg --add-architecture i386; \
    fi && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tar \
        locales \
        procps \
        libstdc++6 \
        $(if [ "$TARGETARCH" = "amd64" ]; then echo "lib32gcc-s1 lib32stdc++6 libc6:i386 libcurl4:i386 libssl3:i386 libbz2-1.0:i386"; fi) && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    groupadd -g 1000 rhino && \
    useradd -u 1000 -g rhino -m -d /home/container -s /bin/bash rhino && \
    mkdir -p /home/container /usr/local/steamcmd /home/container/.steam /home/container/Steam && \
    curl -fsSL --proto '=https' --proto-redir '=https' --retry 3 --retry-delay 2 \
        -o /tmp/steamcmd_linux.tar.gz \
        "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" && \
    tar -tzf /tmp/steamcmd_linux.tar.gz | grep -q 'linux32/steamcmd$' && \
    tar -xzf /tmp/steamcmd_linux.tar.gz -C /usr/local/steamcmd && \
    rm -f /tmp/steamcmd_linux.tar.gz && \
    printf '%s\n' '#!/bin/sh' 'exec /usr/local/steamcmd/steamcmd.sh "$@"' > /usr/local/bin/steamcmd && \
    chmod 0755 /usr/local/bin/steamcmd && \
    sed -i 's|STEAMROOT="$(cd "$(dirname "$0")"|STEAMROOT="$(cd "$(dirname "$(readlink -f "$0")")"|' /usr/local/steamcmd/steamcmd.sh && \
    mkdir -p /home/container/.steam/sdk32 /home/container/.steam/sdk64 && \
    ln -sf /usr/local/steamcmd/linux32/steamclient.so /home/container/.steam/sdk32/steamclient.so 2>/dev/null || true && \
    ln -sf /usr/local/steamcmd/linux64/steamclient.so /home/container/.steam/sdk64/steamclient.so 2>/dev/null || true && \
    chown -R rhino:rhino /home/container /usr/local/steamcmd && \
    find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/* /var/log/*

# Copy statically linked PID 1 launcher
COPY --from=entrypoint-builder /build/target/release/rhino-entrypoint /usr/local/bin/rhino-entrypoint
RUN chmod 755 /usr/local/bin/rhino-entrypoint

WORKDIR /home/container
USER rhino

# Perform initial SteamCMD bootstrap update to cache client runtime files
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        /usr/local/bin/steamcmd +quit; \
    fi

ENTRYPOINT ["/usr/local/bin/rhino-entrypoint"]
CMD ["steamcmd", "+quit"]
