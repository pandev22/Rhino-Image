#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Counter-Strike 2 Dedicated Server
# Downloads/updates CS2 server files via Valve SteamCMD (App ID 730)
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="730"
VALIDATE="${VALIDATE:-1}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Counter-Strike 2 in ${TARGET_DIR}..."

STEAMCMD_BIN=$(command -v steamcmd || echo "/usr/games/steamcmd" || echo "/steamcmd/steamcmd.sh")
if [ ! -x "${STEAMCMD_BIN}" ] && [ -f "/steamcmd/steamcmd.sh" ]; then
    STEAMCMD_BIN="/steamcmd/steamcmd.sh"
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Running SteamCMD for Counter-Strike 2 (App ID ${APP_ID})..."
if [ "${VALIDATE}" = "1" ] || [ "${VALIDATE}" = "true" ]; then
    "${STEAMCMD_BIN}" +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}" validate +quit
else
    "${STEAMCMD_BIN}" +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}" +quit
fi

# Ensure CS2 launcher is executable
chmod +x game/cs2.sh game/bin/linuxsteamrt64/cs2 2>/dev/null || true

# Baseline server.cfg
mkdir -p game/csgo/cfg
CFG_FILE="game/csgo/cfg/server.cfg"
if [ ! -f "${CFG_FILE}" ]; then
    cat <<EOF > "${CFG_FILE}"
hostname "A Rhino Counter-Strike 2 Server"
rcon_password "RhinoCS2SecurePassword!"
sv_cheats 0
sv_lan 0
mp_roundtime 2
mp_maxrounds 24
mp_autoteambalance 1
mp_limitteams 1
bot_quota 0
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Generated baseline game/csgo/cfg/server.cfg."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Counter-Strike 2 server installation completed successfully."
