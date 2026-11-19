#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - BungeeCord Proxy Server
# Downloads latest BungeeCord bootstrap JAR from SpigotMC official Jenkins CI
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

SERVER_JARFILE="${SERVER_JARFILE:-BungeeCord.jar}"
PROXY_PORT="${SERVER_PORT:-25577}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up BungeeCord in ${TARGET_DIR}..."

DOWNLOAD_URL="https://github.com/SpigotMC/BungeeCord/releases/latest/download/BungeeCord.jar"
echo -e "\e[1;33m[rhino-installer]\e[0m Downloading latest BungeeCord build -> ${SERVER_JARFILE}..."
if ! curl -fsSL -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Download failed (HTTP error). The SpigotMC Jenkins CI may be unavailable."
    exit 1
fi
JAR_SIZE=$(stat -c%s "${SERVER_JARFILE}" 2>/dev/null || stat -f%z "${SERVER_JARFILE}")
if [ "${JAR_SIZE:-0}" -lt 102400 ]; then
    echo -e "\e[1;31m[rhino-installer]\e[0m Downloaded file is too small (${JAR_SIZE} bytes) — likely an error response, not a valid JAR."
    rm -f "${SERVER_JARFILE}"
    exit 1
fi

# Create baseline config.yml if not existing
if [ ! -f "config.yml" ]; then
    cat <<EOF > config.yml
server_connect_timeout: 5000
remote_ping_timeout: 5000
forge_support: true
player_limit: -1
permissions:
  default:
  - bungeecord.command.server
  - bungeecord.command.list
  admin:
  - bungeecord.command.alert
  - bungeecord.command.end
  - bungeecord.command.ip
  - bungeecord.command.reload
timeout: 30000
log_pings: true
online_mode: true
servers:
  lobby:
    motd: '&1Just another Rhino BungeeCord'
    address: localhost:25565
    restricted: false
listeners:
- query_port: ${PROXY_PORT}
  motd: '&bRhino &7BungeeCord Proxy'
  tab_list: GLOBAL_PING
  query_enabled: false
  proxy_protocol: false
  forced_hosts:
    pvp.md-5.net: lobby
  ping_passthrough: false
  priorities:
  - lobby
  bind_local_address: true
  host: 0.0.0.0:${PROXY_PORT}
  max_players: 1000
  tab_size: 60
  force_default_server: true
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Generated baseline BungeeCord config.yml on port ${PROXY_PORT}."
fi

echo -e "\e[1;32m[rhino-installer]\e[0m BungeeCord setup completed successfully."
