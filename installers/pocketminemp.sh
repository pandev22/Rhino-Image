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
    RELEASE_JSON=$(curl -fsSL -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/pmmp/PocketMine-MP/releases/latest)
    DOWNLOAD_PHAR_URL=$(echo "${RELEASE_JSON}" | jq -r '.assets[] | select(.name == "PocketMine-MP.phar") | .browser_download_url')
    PMMP_TAG=$(echo "${RELEASE_JSON}" | jq -r '.tag_name')
    echo -e "\e[1;32m[rhino-installer]\e[0m Latest PMMP release: ${PMMP_TAG}"
else
    DOWNLOAD_PHAR_URL="https://github.com/pmmp/PocketMine-MP/releases/download/${PMMP_VERSION}/PocketMine-MP.phar"
fi

if [ -z "${DOWNLOAD_PHAR_URL}" ] || [ "${DOWNLOAD_PHAR_URL}" = "null" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Fallback: using get.pmmp.io installer directly..."
    curl -fsSL https://get.pmmp.io | bash -s - -r
else
    echo -e "\e[1;33m[rhino-installer]\e[0m Downloading PocketMine-MP.phar..."
    if ! curl -fsSL -o "PocketMine-MP.phar" "${DOWNLOAD_PHAR_URL}"; then
        echo -e "\e[1;31m[rhino-installer]\e[0m Download failed (HTTP error). The GitHub release URL may be invalid."
        exit 1
    fi
    PHAR_SIZE=$(stat -c%s "PocketMine-MP.phar" 2>/dev/null || stat -f%z "PocketMine-MP.phar")
    if [ "${PHAR_SIZE:-0}" -lt 102400 ]; then
        echo -e "\e[1;31m[rhino-installer]\e[0m Downloaded file is too small (${PHAR_SIZE} bytes) — likely an error response."
        rm -f "PocketMine-MP.phar"
        exit 1
    fi

    # Setup precompiled PHP binary if bin/php doesn't exist
    if [ ! -f "bin/php7/bin/php" ] && [ ! -f "bin/php" ]; then
        echo -e "\e[1;33m[rhino-installer]\e[0m Downloading PMMP Linux PHP binary package..."
        mkdir -p bin
        PHP_PKG_URL=$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/pmmp/PHP-Binaries/releases/latest" 2>/dev/null | jq -r '
            .assets[] | select(.name | test("Linux.*\\.tar\\.gz$") and (test("debugging") | not)) | .browser_download_url
        ' | head -n 1 || true)

        if [ -z "${PHP_PKG_URL}" ] || [ "${PHP_PKG_URL}" = "null" ]; then
            PHP_PKG_URL="https://github.com/pmmp/PHP-Binaries/releases/download/pm5-php-8.4-latest/PHP-8.4-Linux-x86_64-PM5.tar.gz"
        fi

        if curl -fsSL "${PHP_PKG_URL}" | tar -xz -C bin/; then
            echo -e "\e[1;32m[rhino-installer]\e[0m Installed PHP binary into bin/."
        else
            echo -e "\e[1;33m[rhino-installer]\e[0m Could not download precompiled PHP binary. System PHP will be used if present."
        fi
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
