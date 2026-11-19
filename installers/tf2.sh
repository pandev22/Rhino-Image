#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Team Fortress 2 Dedicated Server (SRCDS)
# Downloads/updates TF2 server files via Valve SteamCMD (App ID 232250)
#
# Security / reliability rules:
# - Uses the real SteamCMD wrapper path, POSIX `set -eu`.
# - SteamCMD success and `srcds_run` are verified.
# - No default RCON password is written: RCON is disabled until the owner sets one.
# ==============================================================================
set -eu
umask 022

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="232250"
VALIDATE="${VALIDATE:-1}"

info() { printf '\033[1;33m[rhino-installer]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[rhino-installer]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[rhino-installer]\033[0m %s\n' "$*" >&2; exit 1; }

info "Setting up Team Fortress 2 in ${TARGET_DIR}..."

STEAMCMD_BIN=""
for candidate in /usr/local/steamcmd/steamcmd.sh /usr/local/bin/steamcmd /usr/games/steamcmd /steamcmd/steamcmd.sh; do
    if [ -x "${candidate}" ]; then
        STEAMCMD_BIN="${candidate}"
        break
    fi
done
[ -n "${STEAMCMD_BIN}" ] || fail "SteamCMD not found (expected /usr/local/steamcmd/steamcmd.sh)"
info "Using SteamCMD: ${STEAMCMD_BIN}"

LOG="/tmp/rhino-steamcmd-$$.log"
trap 'rm -f "${LOG}"' EXIT

set -- +force_install_dir "${TARGET_DIR}" +login anonymous +app_update "${APP_ID}"
if [ "${VALIDATE}" = "1" ] || [ "${VALIDATE}" = "true" ]; then
    set -- "$@" validate
fi
set -- "$@" +quit

info "Running SteamCMD for TF2 (App ID ${APP_ID})..."
if ! "${STEAMCMD_BIN}" "$@" >"${LOG}" 2>&1; then
    cat "${LOG}"
    fail "SteamCMD failed for TF2 (App ID ${APP_ID})"
fi
cat "${LOG}"
grep -Eq "Success! App '${APP_ID}' (fully installed|already up to date)" "${LOG}" \
    || fail "SteamCMD did not report a successful installation for App ID ${APP_ID}"

[ -f "srcds_run" ] || fail "srcds_run is missing after the TF2 installation"
chmod +x srcds_run
[ -f "srcds_linux" ] && chmod +x srcds_linux || true
ok "TF2 server files installed and srcds_run verified."

mkdir -p tf/cfg
CFG_FILE="tf/cfg/server.cfg"
if [ ! -f "${CFG_FILE}" ]; then
    cat <<EOF > "${CFG_FILE}"
hostname "A Rhino Team Fortress 2 Server"
rcon_password ""
sv_contact "admin@rhino.panel"
mp_timelimit 30
mp_maxrounds 5
sv_pure 1
sv_pausable 0
sv_lan 0
EOF
    ok "Generated baseline tf/cfg/server.cfg (RCON disabled)."
fi

ok "Team Fortress 2 server installation completed successfully."
