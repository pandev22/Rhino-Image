#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Unturned Dedicated Server (Smartly Dressed Games)
# Downloads/updates Unturned server files via Valve SteamCMD (App ID 1110390)
#
# Security / reliability rules:
# - Uses the real SteamCMD wrapper path, POSIX `set -eu`.
# - SteamCMD success and the headless binary are verified.
# - SERVER_PORT / MAX_PLAYERS are validated before writing Commands.dat.
# ==============================================================================
set -eu
umask 022

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

APP_ID="1110390"
VALIDATE="${VALIDATE:-1}"
SERVER_PORT="${SERVER_PORT:-27015}"
MAX_PLAYERS="${MAX_PLAYERS:-24}"

info() { printf '\033[1;33m[rhino-installer]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[rhino-installer]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[rhino-installer]\033[0m %s\n' "$*" >&2; exit 1; }

case "${SERVER_PORT}" in
    ""|*[!0-9]*) fail "invalid SERVER_PORT: ${SERVER_PORT}" ;;
esac
[ "${SERVER_PORT}" -ge 1 ] && [ "${SERVER_PORT}" -le 65535 ] || fail "SERVER_PORT out of range"
case "${MAX_PLAYERS}" in
    ""|*[!0-9]*) fail "invalid MAX_PLAYERS: ${MAX_PLAYERS}" ;;
esac

info "Setting up Unturned Dedicated Server in ${TARGET_DIR}..."

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

info "Running SteamCMD for Unturned (App ID ${APP_ID})..."
if ! "${STEAMCMD_BIN}" "$@" >"${LOG}" 2>&1; then
    cat "${LOG}"
    fail "SteamCMD failed for Unturned (App ID ${APP_ID})"
fi
cat "${LOG}"
grep -Eq "Success! App '${APP_ID}' (fully installed|already up to date)" "${LOG}" \
    || fail "SteamCMD did not report a successful installation for App ID ${APP_ID}"

[ -f "Unturned_Headless.x86_64" ] || fail "Unturned_Headless.x86_64 is missing after the installation"
chmod +x Unturned_Headless.x86_64
ok "Unturned server files installed and Unturned_Headless.x86_64 verified."

mkdir -p Servers/Default/Server
COMMANDS_FILE="Servers/Default/Server/Commands.dat"
if [ ! -f "${COMMANDS_FILE}" ]; then
    cat <<EOF > "${COMMANDS_FILE}"
Name A Rhino Unturned Server
Port ${SERVER_PORT}
MaxPlayers ${MAX_PLAYERS}
Map PEI
Mode Normal
Perspective Both
Cheats Off
Cycle 1200
Timeout 300
EOF
    ok "Generated baseline Servers/Default/Server/Commands.dat."
fi

ok "Unturned server installation completed successfully."
