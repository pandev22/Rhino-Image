# syntax=docker/dockerfile:1.7
# ==============================================================================
# Rhino Panel - Official Generic Multi-Runtime Container Image
# Ultra-lightweight Alpine + Bun + Node.js LTS + Python 3 + Astral uv
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build static musl rhino-entrypoint binary (PID 1)
# ------------------------------------------------------------------------------
FROM rust:alpine AS entrypoint-builder
WORKDIR /build

RUN apk add --no-cache musl-dev

COPY entrypoint/ ./
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/build/target \
    cargo build --release --locked && \
    cp target/release/rhino-entrypoint /rhino-entrypoint

# ------------------------------------------------------------------------------
# Stage 2: Hardened Generic Runtime Container
# ------------------------------------------------------------------------------
FROM alpine:3.21 AS runtime

LABEL org.opencontainers.image.title="Rhino Game Server - Generic Polyvalent" \
      org.opencontainers.image.description="Ultra-light multi-runtime (Bun, Node.js LTS, Python 3, uv) with hardened PID 1 entrypoint" \
      org.opencontainers.image.vendor="Rhino Panel" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/pandev22/Rhino-Image"

ENV USER=rhino \
    HOME=/home/container \
    # User-installed tools (~/.local/bin, in the player-writable volume) come LAST: they can
    # never shadow a system binary (cat, sh…) resolved by name.
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/container/.local/bin" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    NODE_ENV=production \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=0 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

# Install runtime dependencies, Node.js LTS, Python 3, and core utilities.
# `apk add` does not upgrade packages already present in the base image: run `apk upgrade` so
# security fixes such as zlib 1.4 (CVE-2026-4738) reach the final image. The weekly rebuild
# reruns this layer with --no-cache.
RUN apk upgrade --no-cache && \
    apk add --no-cache \
        ca-certificates \
        tzdata \
        curl \
        xz \
        git \
        jq \
        bash \
        libstdc++ \
        libgcc \
        nodejs \
        npm \
        python3 \
        py3-pip && \
    # Trim: bytecode caches, test suites, npm cache and docs are dead weight in a read-only rootfs.
    find /usr/lib/python3* /usr/lib/node_modules -type d \( -name __pycache__ -o -name test -o -name tests \) -prune -exec rm -rf {} + 2>/dev/null || true && \
    rm -rf /usr/share/man /usr/share/doc /usr/share/info /root/.cache /root/.npm && \
    addgroup -g 1000 rhino && \
    adduser -u 1000 -G rhino -h /home/container -s /bin/bash -D rhino && \
    mkdir -p /home/container/.local/bin && \
    chown -R rhino:rhino /home/container && \
    chmod 755 /home/container && \
    find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true && \
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Copy pre-compiled Bun binary from official multi-arch Alpine image
COPY --from=oven/bun:alpine /usr/local/bin/bun /usr/local/bin/bun
RUN ln -sf /usr/local/bin/bun /usr/local/bin/bunx

# Copy pre-compiled Astral uv and uvx binaries from official image
COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /usr/local/bin/uv
COPY --from=ghcr.io/astral-sh/uv:0.9 /uvx /usr/local/bin/uvx

# Copy statically linked PID 1 launcher
COPY --from=entrypoint-builder --chmod=755 /rhino-entrypoint /usr/local/bin/rhino-entrypoint

WORKDIR /home/container
USER rhino

ENTRYPOINT ["/usr/local/bin/rhino-entrypoint"]
CMD ["node", "--version"]
