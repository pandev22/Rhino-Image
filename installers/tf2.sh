#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Team Fortress 2 Dedicated Server (SRCDS)
# Downloads/updates TF2 server files via Valve SteamCMD (App ID 232250)
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="232250"
VALIDATE="${VALIDATE:-1}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Team Fortress 2 in ${TARGET_DIR}..."

STEAMCMD_BIN=$(command -v steamcmd || echo "/usr/games/steamcmd" || echo "/steamcmd/steamcmd.sh")
if [ ! -x "${STEAMCMD_BIN}" ] && [ -f "/steamcmd/steamcmd.sh" ]; then
    STEAMCMD_BIN="/steamcmd/steamcmd.sh"
fi

echo -e "\e[1;33m[rhino-installer]\e[0m Running SteamCMD for TF2 (App ID ${APP_ID})..."
if [ "${VALIDATE}" = "1" ] || [ "${VALIDATE}" = "true" ]; then
    "${STEAMCMD_BIN}" +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}" validate +quit
else
    "${STEAMCMD_BIN}" +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}" +quit
fi

# Ensure binaries have executable bit
chmod +x srcds_run srcds_linux 2>/dev/null || true

# Baseline server.cfg
mkdir -p tf/cfg
CFG_FILE="tf/cfg/server.cfg"
if [ ! -f "${CFG_FILE}" ]; then
    cat <<EOF > "${CFG_FILE}"
hostname "A Rhino Team Fortress 2 Server"
rcon_password "RhinoRconSecure123!"
sv_contact "admin@rhino.panel"
mp_timelimit 30
mp_maxrounds 5
sv_pure 1
sv_pausable 0
sv_lan 0
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Generated baseline tf/cfg/server.cfg."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Team Fortress 2 server installation completed successfully."
