#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - PaperMC (Minecraft High-Performance Server)
# Uses the PaperMC Fill v3 API (fill.papermc.io) with checksum verification.
#
# Security / reliability rules:
# - HTTPS only (redirects restricted to HTTPS).
# - Every download goes to a temporary file, is checksum-verified, then renamed.
# - API errors / empty results fail the installation (never save an error body as a JAR).
# - SERVER_JARFILE, MINECRAFT_VERSION, BUILD_NUMBER and SERVER_PORT are validated.
# - The Mojang server JAR is pre-downloaded into Paper's cache when the CDN is
#   reachable; otherwise the install warns instead of failing or hanging.
# - No secrets are written to disk.
# ==============================================================================
set -eu
umask 022

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

MINECRAFT_VERSION="${MINECRAFT_VERSION:-latest}"
BUILD_NUMBER="${BUILD_NUMBER:-latest}"
SERVER_JARFILE="${SERVER_JARFILE:-server.jar}"
SERVER_PORT="${SERVER_PORT:-25565}"
MAX_PLAYERS="${MAX_PLAYERS:-20}"
AUTO_EULA="${AUTO_EULA:-true}"

RHINO_UA="RhinoPanel/1.0 (https://rhino.overnode.fr)"
API_BASE="https://fill.papermc.io/v3/projects/paper"

TMP_DIR="${TARGET_DIR}/.rhino-install-$$"
mkdir -p "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"' EXIT

info() { printf '\033[1;33m[rhino-installer]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[rhino-installer]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[rhino-installer]\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }

need curl
need jq
need sha256sum

# ---------------------------------------------------------------------------
# Input validation (fail closed)
# ---------------------------------------------------------------------------
case "${SERVER_JARFILE}" in
    ""|*/*|*..*|*[!A-Za-z0-9._-]*) fail "invalid SERVER_JARFILE: ${SERVER_JARFILE}" ;;
esac
case "${SERVER_JARFILE}" in
    *.jar) ;;
    *) fail "SERVER_JARFILE must end with .jar" ;;
esac
case "${SERVER_PORT}" in
    ""|*[!0-9]*) fail "invalid SERVER_PORT: ${SERVER_PORT}" ;;
esac
[ "${SERVER_PORT}" -ge 1 ] && [ "${SERVER_PORT}" -le 65535 ] || fail "SERVER_PORT out of range"
case "${MAX_PLAYERS}" in
    ""|*[!0-9]*) fail "invalid MAX_PLAYERS: ${MAX_PLAYERS}" ;;
esac
case "${MINECRAFT_VERSION}" in
    latest) ;;
    *[!0-9A-Za-z._-]*) fail "invalid MINECRAFT_VERSION: ${MINECRAFT_VERSION}" ;;
esac
case "${BUILD_NUMBER}" in
    latest) ;;
    *[!0-9]*) fail "invalid BUILD_NUMBER: ${BUILD_NUMBER}" ;;
esac

fetch() {
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300 \
        --proto '=https' --proto-redir '=https' \
        -H "User-Agent: ${RHINO_UA}" "$1"
}

download() {
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 900 \
        --proto '=https' --proto-redir '=https' \
        -H "User-Agent: ${RHINO_UA}" -o "$2" "$1"
}

info "Starting PaperMC setup in ${TARGET_DIR}..."

# ---------------------------------------------------------------------------
# Resolve the latest supported Minecraft version
# ---------------------------------------------------------------------------
if [ "${MINECRAFT_VERSION}" = "latest" ]; then
    info "Resolving the latest supported Minecraft version from the Fill API..."
    VERSIONS_DATA=$(fetch "${API_BASE}/versions") || fail "cannot reach the PaperMC Fill API"
    MINECRAFT_VERSION=$(printf '%s' "${VERSIONS_DATA}" | jq -er '
        ([.versions[] | select(.version.support.status == "SUPPORTED")][0].version.id)
        // .versions[0].version.id
    ') || fail "cannot resolve the latest Minecraft version"
    case "${MINECRAFT_VERSION}" in
        ""|*[!0-9A-Za-z._-]*) fail "invalid Minecraft version returned by the API" ;;
    esac
    ok "Resolved Minecraft version: ${MINECRAFT_VERSION}"
fi

# ---------------------------------------------------------------------------
# Resolve build + checksum (the API returns builds newest-first)
# ---------------------------------------------------------------------------
info "Fetching Paper builds for ${MINECRAFT_VERSION}..."
BUILDS_DATA=$(fetch "${API_BASE}/versions/${MINECRAFT_VERSION}/builds") \
    || fail "cannot fetch Paper builds for ${MINECRAFT_VERSION}"

if [ "${BUILD_NUMBER}" = "latest" ]; then
    BUILD_JSON=$(printf '%s' "${BUILDS_DATA}" | jq -ec '
        if any(.channel == "STABLE") then
            (map(select(.channel == "STABLE")) | first)
        else
            .[0]
        end
    ') || fail "no Paper build available for ${MINECRAFT_VERSION}"
else
    BUILD_JSON=$(printf '%s' "${BUILDS_DATA}" | jq -ec --argjson id "${BUILD_NUMBER}" '
        map(select(.id == $id)) | first
    ') || fail "Paper build #${BUILD_NUMBER} not found for ${MINECRAFT_VERSION}"
fi

DOWNLOAD_URL=$(printf '%s' "${BUILD_JSON}" | jq -er '.downloads["server:default"].url') \
    || fail "Paper download URL missing"
SHA256=$(printf '%s' "${BUILD_JSON}" | jq -er '.downloads["server:default"].checksums.sha256') \
    || fail "Paper checksum missing"
RESOLVED_BUILD=$(printf '%s' "${BUILD_JSON}" | jq -er '.id') \
    || fail "Paper build id missing"
case "${DOWNLOAD_URL}" in
    https://*) ;;
    *) fail "refusing a non-HTTPS Paper download URL" ;;
esac
case "${SHA256}" in
    *[!0-9a-fA-F]*|"") fail "invalid Paper checksum" ;;
esac
[ "${#SHA256}" -eq 64 ] || fail "invalid Paper checksum length"

ok "Resolved Paper build #${RESOLVED_BUILD}"

# ---------------------------------------------------------------------------
# Download the Paper JAR atomically
# ---------------------------------------------------------------------------
info "Downloading Paper ${MINECRAFT_VERSION} build ${RESOLVED_BUILD}..."
download "${DOWNLOAD_URL}" "${TMP_DIR}/paper.jar" || fail "Paper download failed"
printf '%s  %s\n' "${SHA256}" "${TMP_DIR}/paper.jar" | sha256sum -c - >/dev/null \
    || fail "Paper checksum verification failed"
mv -f "${TMP_DIR}/paper.jar" "${SERVER_JARFILE}"
chmod 0644 "${SERVER_JARFILE}"
ok "Paper JAR saved to ${SERVER_JARFILE}"

# ---------------------------------------------------------------------------
# Best-effort Mojang server JAR cache (Paper's META-INF/download-context)
# Paper (paperclip) reads cache/mojang_<version>.jar and verifies its SHA-256.
# The context embedded in the Paper JAR provides the exact URL and hash, so we
# do not depend on the Mojang version manifest. On hosts where the container
# cannot reach Mojang's CDN (Azure), the install still succeeds but a warning
# tells the operator to pre-seed the cache from the host (where the network
# usually works).
# ---------------------------------------------------------------------------
CACHE_DIR="cache"
mkdir -p "${CACHE_DIR}"
PAPER_REQUIRE_MOJANG_CACHE="${PAPER_REQUIRE_MOJANG_CACHE:-0}"
mojang_cache_ready=0

if command -v python3 >/dev/null 2>&1; then
    CONTEXT=$(python3 -c '
import sys, zipfile
try:
    print(zipfile.ZipFile(sys.argv[1]).read("META-INF/download-context").decode())
except Exception:
    pass
' "${SERVER_JARFILE}" 2>/dev/null || true)
    if [ -n "${CONTEXT}" ]; then
        printf '%s\n' "${CONTEXT}" | tr -d '\r' > "${TMP_DIR}/download-context"
        while IFS="$(printf '\t')" read -r ctx_hash ctx_url ctx_name; do
            case "${ctx_name}" in
                mojang_*.jar) ;;
                *) continue ;;
            esac
            case "${ctx_name}" in
                */*|*..*) continue ;;
            esac
            case "${ctx_url}" in
                https://*) ;;
                *) continue ;;
            esac
            case "${ctx_hash}" in
                *[!0-9a-fA-F]*|"") continue ;;
            esac
            [ "${#ctx_hash}" -eq 64 ] || continue

            CACHE_JAR="${CACHE_DIR}/${ctx_name}"
            if [ -f "${CACHE_JAR}" ] && \
               printf '%s  %s\n' "${ctx_hash}" "${CACHE_JAR}" | sha256sum -c - >/dev/null 2>&1; then
                ok "Mojang server JAR already cached and valid: ${CACHE_JAR}"
                mojang_cache_ready=1
                continue
            fi

            info "Pre-downloading ${ctx_name} (Mojang CDN)..."
            if download "${ctx_url}" "${TMP_DIR}/${ctx_name}" && \
               printf '%s  %s\n' "${ctx_hash}" "${TMP_DIR}/${ctx_name}" | sha256sum -c - >/dev/null 2>&1; then
                mv -f "${TMP_DIR}/${ctx_name}" "${CACHE_JAR}"
                chmod 0644 "${CACHE_JAR}"
                ok "Mojang server JAR cached at ${CACHE_JAR}"
                mojang_cache_ready=1
                continue
            fi

            # Fallback: the official launcher CDN uses the same object id (SHA-1).
            OBJECT=$(printf '%s' "${ctx_url}" | sed -n 's#.*/objects/\([^/]*\)/.*#\1#p')
            if [ -n "${OBJECT}" ]; then
                FALLBACK_URL="https://launcher.mojang.com/v1/objects/${OBJECT}/server.jar"
                info "Retrying ${ctx_name} from ${FALLBACK_URL}..."
                if download "${FALLBACK_URL}" "${TMP_DIR}/${ctx_name}" && \
                   printf '%s  %s\n' "${ctx_hash}" "${TMP_DIR}/${ctx_name}" | sha256sum -c - >/dev/null 2>&1; then
                    mv -f "${TMP_DIR}/${ctx_name}" "${CACHE_JAR}"
                    chmod 0644 "${CACHE_JAR}"
                    ok "Mojang server JAR cached at ${CACHE_JAR}"
                    mojang_cache_ready=1
                    continue
                fi
            fi

            printf '\033[1;33m[rhino-installer]\033[0m WARNING: cannot download %s from the Mojang CDN.\n' \
                "${ctx_name}" >&2
        done < "${TMP_DIR}/download-context"
    fi
else
    printf '\033[1;33m[rhino-installer]\033[0m WARNING: python3 unavailable, skipping the Mojang cache check.\n' >&2
fi

if [ "${mojang_cache_ready}" != "1" ]; then
    printf '\033[1;33m[rhino-installer]\033[0m WARNING: Mojang cache not available. If the first start hangs on\n' >&2
    printf '\033[1;33m[rhino-installer]\033[0m "Downloading mojang_%s.jar", pre-seed cache/mojang_%s.jar from the host.\n' \
        "${MINECRAFT_VERSION}" "${MINECRAFT_VERSION}" >&2
    if [ "${PAPER_REQUIRE_MOJANG_CACHE}" = "1" ] || [ "${PAPER_REQUIRE_MOJANG_CACHE}" = "true" ]; then
        fail "PAPER_REQUIRE_MOJANG_CACHE is enabled and the Mojang cache is missing"
    fi
fi

# ---------------------------------------------------------------------------
# EULA + baseline server.properties
# ---------------------------------------------------------------------------
if [ "${AUTO_EULA}" = "true" ] || [ "${AUTO_EULA}" = "1" ]; then
    echo "eula=true" > eula.txt
    ok "EULA accepted (eula.txt created)."
fi

if [ ! -f "server.properties" ]; then
    cat <<EOF > server.properties
server-port=${SERVER_PORT}
motd=A Rhino Paper Server
max-players=${MAX_PLAYERS}
online-mode=true
enable-rcon=false
white-list=false
view-distance=10
difficulty=easy
gamemode=survival
EOF
    ok "Created baseline server.properties on port ${SERVER_PORT}."
fi

ok "Paper server installation completed successfully (build ${RESOLVED_BUILD})."
