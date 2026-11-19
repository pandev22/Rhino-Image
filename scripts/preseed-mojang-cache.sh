#!/usr/bin/env bash
# ==============================================================================
# Rhino - Pre-seed Paper's Mojang cache from the HOST
#
# Why: on some hosts the Docker bridge cannot reach Mojang's Azure CDN, while
# the host itself can. Paper's first start then hangs on
# "Downloading mojang_<version>.jar". The install script warns, and this helper
# downloads the exact object referenced by Paper's own
# META-INF/download-context (SHA-256 verified) into <volume>/cache/.
#
# Usage (as root on the Action host):
#   scripts/preseed-mojang-cache.sh /var/www/rhino/servers/<server_id>
#
# The script never trusts the URL blindly: the context hash is checked with
# sha256sum before the file is moved into place. HTTPS only.
# ==============================================================================
set -euo pipefail
umask 022

VOLUME="${1:-}"
if [ -z "${VOLUME}" ]; then
    echo "usage: $0 <server-volume>" >&2
    exit 2
fi
case "${VOLUME}" in
    /*) ;;
    *) echo "the volume path must be absolute" >&2; exit 2 ;;
esac

JAR="${VOLUME}/server.jar"
[ -f "${JAR}" ] || { echo "missing ${JAR}" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 1; }

CACHE_DIR="${VOLUME}/cache"
mkdir -p "${CACHE_DIR}"
TMP_FILE="${CACHE_DIR}/.mojang-cache.$$"
trap 'rm -f "${TMP_FILE}"' EXIT

download() {
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 900 \
        --proto '=https' --proto-redir '=https' -o "$2" "$1"
}

CONTEXT=$(python3 -c '
import sys, zipfile
try:
    print(zipfile.ZipFile(sys.argv[1]).read("META-INF/download-context").decode())
except Exception:
    pass
' "${JAR}" 2>/dev/null || true)
[ -n "${CONTEXT}" ] || { echo "no META-INF/download-context in ${JAR}" >&2; exit 1; }

printf '%s\n' "${CONTEXT}" | tr -d '\r' > "${TMP_FILE}.context"
trap 'rm -f "${TMP_FILE}" "${TMP_FILE}.context"' EXIT

found=0
while IFS="$(printf '\t')" read -r hash url name; do
    case "${name}" in
        mojang_*.jar) ;;
        *) continue ;;
    esac
    case "${name}" in
        */*|*..*) echo "refusing unsafe cache filename: ${name}" >&2; continue ;;
    esac
    case "${url}" in
        https://*) ;;
        *) echo "refusing non-HTTPS URL: ${url}" >&2; continue ;;
    esac
    case "${hash}" in
        *[!0-9a-fA-F]*|"") continue ;;
    esac
    [ "${#hash}" -eq 64 ] || continue

    found=1
    target="${CACHE_DIR}/${name}"
    if [ -f "${target}" ] &&
       printf '%s  %s\n' "${hash}" "${target}" | sha256sum -c - >/dev/null 2>&1; then
        echo "already valid: ${target}"
        continue
    fi

    echo "downloading ${name}..."
    if download "${url}" "${TMP_FILE}" &&
       printf '%s  %s\n' "${hash}" "${TMP_FILE}" | sha256sum -c - >/dev/null 2>&1; then
        mv -f "${TMP_FILE}" "${target}"
    else
        object=$(printf '%s' "${url}" | sed -n 's#.*/objects/\([^/]*\)/.*#\1#p')
        [ -n "${object}" ] || { echo "download failed: ${url}" >&2; continue; }
        fallback="https://launcher.mojang.com/v1/objects/${object}/server.jar"
        echo "retrying from ${fallback}..."
        if ! download "${fallback}" "${TMP_FILE}" ||
           ! printf '%s  %s\n' "${hash}" "${TMP_FILE}" | sha256sum -c - >/dev/null 2>&1; then
            echo "download/checksum failed for ${name}" >&2
            continue
        fi
        mv -f "${TMP_FILE}" "${target}"
    fi
    chmod 0644 "${target}"
    chown 1000:1000 "${target}" 2>/dev/null || true
    echo "seeded: ${target}"
done < "${TMP_FILE}.context"

[ "${found}" = "1" ] || { echo "no mojang_*.jar entry found in the Paper context" >&2; exit 1; }
echo "Mojang cache ready in ${CACHE_DIR}"
