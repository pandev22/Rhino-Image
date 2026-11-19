# syntax=docker/dockerfile:1.7
# ==============================================================================
# Rhino Panel - Official Windows Runtime Container Image (Wine + WoW64 + Xvfb)
# Hardened Debian 13 (Trixie) Slim + Wine WoW64 32/64-bit + Headless Xvfb
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
# Stage 2: Hardened Wine WoW64 Runtime
# ------------------------------------------------------------------------------
FROM debian:trixie-slim AS runtime

ARG TARGETARCH

LABEL org.opencontainers.image.title="Rhino Game Server - Wine WoW64" \
      org.opencontainers.image.description="High-performance Windows runtime for dedicated game servers using Wine WoW64 and Xvfb" \
      org.opencontainers.image.vendor="Rhino Panel" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/pandev22/Rhino-Image"

ENV DEBIAN_FRONTEND=noninteractive \
    USER=rhino \
    HOME=/home/container \
    WINEPREFIX=/home/container/.wine \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    DISPLAY=:99 \
    DISPLAY_WIDTH=1024 \
    DISPLAY_HEIGHT=768 \
    DISPLAY_DEPTH=16 \
    RHINO_START_XVFB=1

# Install Wine 64-bit & 32-bit WoW64 runtime + Xvfb headless display server
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        dpkg --add-architecture i386; \
    fi && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        procps \
        tar \
        p7zip-full \
        cabextract \
        xvfb \
        xauth \
        wine \
        wine64 \
        $(if [ "$TARGETARCH" = "amd64" ]; then echo "wine32:i386 libwine:i386"; fi) && \
    groupadd -g 1000 rhino && \
    useradd -u 1000 -g rhino -m -d /home/container -s /bin/bash rhino && \
    mkdir -p /home/container/.wine /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    chown -R rhino:rhino /home/container && \
    find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/* /var/log/*

# Copy statically linked PID 1 launcher
COPY --from=entrypoint-builder /build/target/release/rhino-entrypoint /usr/local/bin/rhino-entrypoint
RUN chmod 755 /usr/local/bin/rhino-entrypoint

WORKDIR /home/container
USER rhino

# Pre-initialize basic wine prefix as rhino user to accelerate first startup
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        wineboot --init 2>/dev/null || true; \
    fi

ENTRYPOINT ["/usr/local/bin/rhino-entrypoint"]
CMD ["wine64", "--version"]
