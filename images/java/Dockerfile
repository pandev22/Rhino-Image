# syntax=docker/dockerfile:1.7
# ==============================================================================
# Rhino Panel - Official Hardened Java Container Image
# Multi-version Eclipse Temurin JRE (8, 17, 21, 25)
# Shell-less / Hardened Slim Runtime for High-Performance Game Servers
# ==============================================================================

ARG JAVA_VERSION=21

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
# Stage 2: Hardened Runtime Container
# ------------------------------------------------------------------------------
FROM eclipse-temurin:${JAVA_VERSION}-jre-noble AS runtime

ARG JAVA_VERSION
ARG HARDEN_REMOVE_SHELL=true

LABEL org.opencontainers.image.title="Rhino Game Server - Java ${JAVA_VERSION}" \
      org.opencontainers.image.description="Hardened, ultra-secure JRE runtime with PID 1 Rust entrypoint for Rhino Panel" \
      org.opencontainers.image.vendor="Rhino Panel" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/pandev22/Rhino-Image" \
      rhino.image.java_version="${JAVA_VERSION}"

# Environment configuration
ENV DEBIAN_FRONTEND=noninteractive \
    USER=rhino \
    HOME=/home/container \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Install essential native libraries required by game servers (fonts, graphics, certificates)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        tzdata \
        fontconfig \
        libfreetype6 \
        procps \
        curl && \
    groupadd -g 1000 rhino && \
    useradd -u 1000 -g rhino -m -d /home/container -s /usr/sbin/nologin rhino && \
    mkdir -p /home/container && \
    chown -R rhino:rhino /home/container && \
    chmod 755 /home/container && \
    find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true && \
    apt-get purge -y --auto-remove curl && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/* /var/log/*

# Copy statically-linked musl entrypoint binary
COPY --from=entrypoint-builder /build/target/release/rhino-entrypoint /usr/local/bin/rhino-entrypoint
RUN chmod 755 /usr/local/bin/rhino-entrypoint

# Conditionally remove standard interactive shells for zero-day RCE mitigation (Log4Shell / Command Injection)
# When removed, attackers cannot execute reverse shells (/bin/sh, /bin/bash).
RUN if [ "${HARDEN_REMOVE_SHELL}" = "true" ]; then \
        rm -f /bin/bash /bin/rbash /bin/dash 2>/dev/null || true; \
    fi

WORKDIR /home/container
USER rhino

ENTRYPOINT ["/usr/local/bin/rhino-entrypoint"]
CMD ["java", "-version"]
