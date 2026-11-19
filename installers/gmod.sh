#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Garry's Mod Dedicated Server (SRCDS)
# Downloads/updates Garry's Mod server files via Valve SteamCMD (App ID 4020)
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="4020"
VALIDATE="${VALIDATE:-1}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Garry's Mod in ${TARGET_DIR}..."

STEAMCMD_BIN=$(command -v steamcmd || echo "/usr/games/steamcmd" || echo "/steamcmd/steamcmd.sh")
if [ ! -x "${STEAMCMD_BIN}" ] && [ -f "/steamcmd/steamcmd.sh" ]; then
    STEAMCMD_BIN="/steamcmd/steamcmd.sh"
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Running SteamCMD for Garry's Mod (App ID ${APP_ID})..."
if [ "${VALIDATE}" = "1" ] || [ "${VALIDATE}" = "true" ]; then
    "${STEAMCMD_BIN}" +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}" validate +quit
else
    "${STEAMCMD_BIN}" +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}" +quit
fi

# Ensure binaries have executable bit
chmod +x srcds_run srcds_linux 2>/dev/null || true

# Baseline server.cfg
mkdir -p garrysmod/cfg
CFG_FILE="garrysmod/cfg/server.cfg"
if [ ! -f "${CFG_FILE}" ]; then
    cat <<EOF > "${CFG_FILE}"
hostname "A Rhino Garry's Mod Server"
rcon_password "RhinoGmodAdminPass123!"
sv_password ""
sv_lan 0
sv_region 255
sbox_maxprops 150
sbox_maxragdolls 10
sbox_maxvehicles 6
sbox_maxballoons 10
sbox_maxeffects 50
sbox_maxdynamite 10
sbox_maxlamps 10
sbox_maxthrusters 30
sbox_maxwheels 20
sbox_maxhoverballs 20
sbox_maxbuttons 20
sbox_maxemitters 20
sbox_godmode 0
sbox_noclip 1
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Generated baseline garrysmod/cfg/server.cfg."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Garry's Mod server installation completed successfully."
