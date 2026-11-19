#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Unturned Dedicated Server (Smartly Dressed Games)
# Downloads/updates Unturned server files via Valve SteamCMD (App ID 1110390)
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="1110390"
VALIDATE="${VALIDATE:-1}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Unturned Dedicated Server in ${TARGET_DIR}..."

STEAMCMD_BIN=$(command -v steamcmd || echo "/usr/games/steamcmd" || echo "/steamcmd/steamcmd.sh")
if [ ! -x "${STEAMCMD_BIN}" ] && [ -f "/steamcmd/steamcmd.sh" ]; then
    STEAMCMD_BIN="/steamcmd/steamcmd.sh"
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Running SteamCMD for Unturned (App ID ${APP_ID})..."
if [ "${VALIDATE}" = "1" ] || [ "${VALIDATE}" = "true" ]; then
    "${STEAMCMD_BIN}" +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}" validate +quit
else
    "${STEAMCMD_BIN}" +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}" +quit
fi

# Ensure executable permissions
chmod +x Unturned_Headless.x86_64 2>/dev/null || true

# Baseline Commands.dat
mkdir -p Servers/Default/Server
COMMANDS_FILE="Servers/Default/Server/Commands.dat"
if [ ! -f "${COMMANDS_FILE}" ]; then
    cat <<EOF > "${COMMANDS_FILE}"
Name A Rhino Unturned Server
Port ${SERVER_PORT:-27015}
MaxPlayers ${MAX_PLAYERS:-24}
Map PEI
Mode Normal
Perspective Both
Cheats Off
Cycle 1200
Timeout 300
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Generated baseline Servers/Default/Server/Commands.dat."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Unturned server installation completed successfully."
