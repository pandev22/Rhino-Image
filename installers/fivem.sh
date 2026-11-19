#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - FiveM Multiplayer Server (CitizenFX)
# Downloads the official Linux build artifact and baseline cfx-server-data resources.
#
# Security / reliability rules:
# - HTTPS only, fail-closed artifact resolution (no stale hardcoded build).
# - The FiveM license key is required and is never printed; it is written only to
#   the server's own server.cfg.
# - SERVER_PORT is validated.
# - Archives are downloaded to a temporary file and extracted with `tar -xJ`.
# ==============================================================================
set -eu
umask 022

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

FIVEM_VERSION="${FIVEM_VERSION:-latest}"
FIVEM_LICENSE="${FIVEM_LICENSE:-}"
SERVER_PORT="${SERVER_PORT:-30120}"

info() { printf '\033[1;33m[rhino-installer]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[rhino-installer]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[rhino-installer]\033[0m %s\n' "$*" >&2; exit 1; }

case "${SERVER_PORT}" in
    ""|*[!0-9]*) fail "invalid SERVER_PORT: ${SERVER_PORT}" ;;
esac
[ "${SERVER_PORT}" -ge 1 ] && [ "${SERVER_PORT}" -le 65535 ] || fail "SERVER_PORT out of range"
[ -n "${FIVEM_LICENSE}" ] || fail "FIVEM_LICENSE is required (CitizenFX Keymaster server key)"

TMP_DIR="${TARGET_DIR}/.rhino-install-$$"
mkdir -p "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"' EXIT

info "Setting up FiveM Server in ${TARGET_DIR}..."

ARTIFACTS_PAGE_URL="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
info "Resolving the recommended FiveM Linux server artifact..."
LATEST_PATH=$(curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 120 \
    --proto '=https' --proto-redir '=https' "${ARTIFACTS_PAGE_URL}" \
    | grep -oE '[0-9]+-[a-f0-9]+/fx\.tar\.xz' | head -n 1 || true)
[ -n "${LATEST_PATH}" ] || fail "cannot resolve the FiveM artifact (runtime.fivem.net page changed)"

DOWNLOAD_URL="${ARTIFACTS_PAGE_URL}${LATEST_PATH}"
info "Downloading FiveM fx.tar.xz..."
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 900 \
    --proto '=https' --proto-redir '=https' \
    -o "${TMP_DIR}/fx.tar.xz" "${DOWNLOAD_URL}" || fail "FiveM artifact download failed"
mkdir -p alpine
tar -xJf "${TMP_DIR}/fx.tar.xz" -C "${TARGET_DIR}/alpine/" || fail "FiveM artifact extraction failed"
ok "FiveM server files extracted."

if [ ! -d "resources" ] && [ ! -d "cfx-server-data" ]; then
    info "Downloading baseline cfx-server-data default resources..."
    if command -v git >/dev/null 2>&1; then
        git clone --depth=1 https://github.com/citizenfx/cfx-server-data.git "${TMP_DIR}/cfx-data" \
            || fail "cannot clone cfx-server-data"
        cp -rn "${TMP_DIR}/cfx-data/resources" ./resources 2>/dev/null || true
    else
        mkdir -p "resources/[default]"
        info "git unavailable: created an empty resources directory."
    fi
fi

if [ ! -f "server.cfg" ]; then
    cat <<EOF > server.cfg
# Rhino Panel - FiveM Server Configuration
endpoint_add_tcp "0.0.0.0:${SERVER_PORT}"
endpoint_add_udp "0.0.0.0:${SERVER_PORT}"

sv_hostname "A Rhino FiveM Server"
sv_licenseKey "${FIVEM_LICENSE}"
sv_maxclients 32

ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure hardcap

# Add system admins
add_ace group.admin command allow
add_ace group.admin command.quit deny
EOF
    chmod 0600 server.cfg
    ok "Created baseline server.cfg on port ${SERVER_PORT} (contains the license key, mode 0600)."
fi

if [ -f "alpine/run.sh" ]; then
    chmod +x alpine/run.sh
elif [ -f "alpine/opt/cfx-server/run.sh" ]; then
    chmod +x alpine/opt/cfx-server/run.sh
else
    fail "FiveM run.sh is missing after extraction"
fi

ok "FiveM server installation completed successfully."
