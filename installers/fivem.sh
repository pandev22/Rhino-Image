#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - FiveM Multiplayer Server (CitizenFX)
# Downloads official Linux build artifact & sets up cfx-server-data resources
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

FIVEM_VERSION="${FIVEM_VERSION:-latest}"
FIVEM_LICENSE="${FIVEM_LICENSE:-}"
SERVER_PORT="${SERVER_PORT:-30120}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up FiveM Server in ${TARGET_DIR}..."

ARTIFACTS_PAGE_URL="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
echo -e "\e[1;33m[rhino-installer]\e[0m Resolving recommended FiveM Linux server artifact..."

# Fetch HTML and extract latest recommended build URL (e.g. ./13824-7df8.../fx.tar.xz)
LATEST_PATH=$(curl -sSL "${ARTIFACTS_PAGE_URL}" | grep -oE '\./[0-9]+-[a-f0-9]+/fx\.tar\.xz' | head -n 1 | sed 's|^\./||' || true)

if [ -z "${LATEST_PATH}" ]; then
    LATEST_PATH="13824-7df8f8c09a8966cbbdd03d09a2ad4f77de29f34a/fx.tar.xz"
fi

DOWNLOAD_URL="${ARTIFACTS_PAGE_URL}${LATEST_PATH}"
echo -e "\e[1;33m[rhino-installer]\e[0m Downloading FiveM fx.tar.xz from ${DOWNLOAD_URL}..."
mkdir -p alpine
curl -sSL "${DOWNLOAD_URL}" | tar -xJ -C "${TARGET_DIR}/alpine/"

# Download cfx-server-data resources if not present
if [ ! -d "resources" ] && [ ! -d "cfx-server-data" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Downloading baseline cfx-server-data default resources..."
    if command -v git &>/dev/null; then
        git clone --depth=1 https://github.com/citizenfx/cfx-server-data.git /tmp/cfx-data
        cp -rn /tmp/cfx-data/resources ./resources 2>/dev/null || true
        rm -rf /tmp/cfx-data
    else
        mkdir -p resources/[default]
    fi
fi

# Baseline server.cfg
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
    echo -e "\e[1;32m[rhino-installer]\e[0m Created baseline server.cfg on port ${SERVER_PORT}."
fi

# Ensure run.sh is executable
chmod +x alpine/opt/cfx-server/run.sh alpine/run.sh 2>/dev/null || true

echo -e "\e[1;32m[rhino-installer]\e[0m FiveM server installation completed successfully."
