#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - PocketMine-MP (Minecraft Bedrock Server)
# Downloads PocketMine-MP.phar from official GitHub releases and bundled PHP binary
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

PMMP_VERSION="${PMMP_VERSION:-latest}"
BEDROCK_PORT="${SERVER_PORT:-19132}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up PocketMine-MP in ${TARGET_DIR}..."

# Query GitHub API for latest release
if [ "${PMMP_VERSION}" = "latest" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Fetching latest release info from GitHub pmmp/PocketMine-MP..."
    RELEASE_JSON=$(curl -sSL -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/pmmp/PocketMine-MP/releases/latest)
    DOWNLOAD_PHAR_URL=$(echo "${RELEASE_JSON}" | jq -r '.assets[] | select(.name == "PocketMine-MP.phar") | .browser_download_url')
    PMMP_TAG=$(echo "${RELEASE_JSON}" | jq -r '.tag_name')
    echo -e "\e[1;32m[rhino-installer]\e[0m Latest PMMP release: ${PMMP_TAG}"
else
    DOWNLOAD_PHAR_URL="https://github.com/pmmp/PocketMine-MP/releases/download/${PMMP_VERSION}/PocketMine-MP.phar"
fi

if [ -z "${DOWNLOAD_PHAR_URL}" ] || [ "${DOWNLOAD_PHAR_URL}" = "null" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Fallback: using get.pmmp.io installer directly..."
    curl -sSL https://get.pmmp.io | bash -s - -r
else
    echo -e "\e[1;33m[rhino-installer]\e[0m Downloading PocketMine-MP.phar..."
    curl -sSL -o "PocketMine-MP.phar" "${DOWNLOAD_PHAR_URL}"

    # Setup precompiled PHP binary if bin/php doesn't exist
    if [ ! -f "bin/php7/bin/php" ] && [ ! -f "bin/php" ]; then
        echo -e "\e[1;33m[rhino-installer]\e[0m Downloading PMMP Linux PHP binary package..."
        mkdir -p bin
        PHP_PKG_URL="https://github.com/pmmp/PHP-Binaryer/releases/download/php-8.2-latest/PHP-Linux-x86_64.tar.gz"
        curl -sSL "${PHP_PKG_URL}" | tar -xz -C bin/ || true
    fi
fi

# Baseline server.properties
if [ ! -f "server.properties" ]; then
    cat <<EOF > server.properties
server-name=A Rhino PocketMine Server
server-port=${BEDROCK_PORT}
server-portv6=19133
gamemode=0
max-players=20
spawn-protection=16
white-list=off
enable-query=on
enable-rcon=off
motd=A Rhino PocketMine-MP Server
view-distance=8
auto-save=on
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Created baseline server.properties for Bedrock port ${BEDROCK_PORT}."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m PocketMine-MP installation completed successfully."
