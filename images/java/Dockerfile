# syntax=docker/dockerfile:1.7
# ==============================================================================
# Rhino Panel - Official Java Container Image (Temurin JRE 8, 17, 21, 25)
# Distroless runtime: glibc + JRE + PID 1 entrypoint. No shell, no package manager,
# no curl: smaller image, smaller attack surface (Log4Shell-style reverse shells
# have nothing to run), faster pull and cold start.
# ==============================================================================

ARG JAVA_VERSION=21

# ------------------------------------------------------------------------------
# Stage 1: static musl rhino-entrypoint (PID 1), built natively for the TARGET arch
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
# Stage 2: trim the JRE (headless server: no X11 / splash / man pages / sources)
# ------------------------------------------------------------------------------
FROM eclipse-temurin:${JAVA_VERSION}-jre-noble AS jre
RUN set -eux; \
    JH=/opt/java/openjdk; \
    # The CA store is a symlink into /etc/ssl: materialise it, the final image has no /etc/ssl/certs/java.
    for f in $(find "$JH" -name cacerts -type l); do cp --remove-destination "$(readlink -f "$f")" "$f"; done; \
    rm -rf "$JH/man" "$JH/legal" "$JH/lib/src.zip" "$JH/ASSEMBLY_EXCEPTION" "$JH/THIRD_PARTY_README"; \
    find "$JH" \( -name '*.diz' -o -name '*.debuginfo' -o -name 'libawt_xawt.so' -o -name 'libsplashscreen.so' \
        -o -name 'libjawt.so' -o -name 'libjsound.so' \) -delete; \
    mkdir -p /rootfs/home/container; \
    chown -R 1000:1000 /rootfs/home/container; \
    chmod 755 /rootfs/home/container; \
    printf 'root:x:0:0:root:/root:/sbin/nologin\nrhino:x:1000:1000:rhino:/home/container:/sbin/nologin\n' > /rootfs/passwd; \
    printf 'root:x:0:\nrhino:x:1000:\n' > /rootfs/group

# ------------------------------------------------------------------------------
# Stage 3: final runtime
# ------------------------------------------------------------------------------
FROM gcr.io/distroless/cc-debian13 AS runtime

ARG JAVA_VERSION

LABEL org.opencontainers.image.title="Rhino Game Server - Java ${JAVA_VERSION}" \
      org.opencontainers.image.description="Distroless Temurin JRE with PID 1 Rust entrypoint and container-aware JVM tuning for Rhino Panel" \
      org.opencontainers.image.vendor="Rhino Panel" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/pandev22/Rhino-Image" \
      rhino.image.java_version="${JAVA_VERSION}"

ENV USER=rhino \
    HOME=/home/container \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:/usr/local/bin:/usr/bin:/bin" \
    RHINO_JAVA_MAJOR=${JAVA_VERSION}

COPY --from=jre /opt/java/openjdk /opt/java/openjdk
COPY --from=jre /rootfs/passwd /rootfs/group /etc/
COPY --from=jre --chown=1000:1000 /rootfs/home/container /home/container
COPY --from=entrypoint-builder /rhino-entrypoint /usr/local/bin/rhino-entrypoint

WORKDIR /home/container
USER 1000:1000

ENTRYPOINT ["/usr/local/bin/rhino-entrypoint"]
CMD ["java", "-version"]
