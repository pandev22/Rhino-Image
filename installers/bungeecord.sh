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

DOWNLOAD_URL="https://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar"
echo -e "\e[1;33m[rhino-installer]\e[0m Downloading latest BungeeCord build -> ${SERVER_JARFILE}..."
curl -sSL -o "${SERVER_JARFILE}" "${DOWNLOAD_URL}"

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
