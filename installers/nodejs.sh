#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Node.js App & Bot Runtime
# Prepares Node.js environment, installs dependencies, and sets up starter project
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

MAIN_FILE="${MAIN_FILE:-index.js}"
AUTO_INSTALL="${AUTO_INSTALL:-true}"
SERVER_PORT="${SERVER_PORT:-3000}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Node.js project in ${TARGET_DIR}..."

# If package.json doesn't exist, create a clean starter template
if [ ! -f "package.json" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Generating baseline package.json and ${MAIN_FILE}..."
    cat <<EOF > package.json
{
  "name": "rhino-node-app",
  "version": "1.0.0",
  "description": "Hosted on Rhino Panel",
  "main": "${MAIN_FILE}",
  "type": "module",
  "scripts": {
    "start": "node ${MAIN_FILE}"
  },
  "dependencies": {}
}
EOF

    cat <<EOF > "${MAIN_FILE}"
import http from 'node:http';

const port = process.env.SERVER_PORT || ${SERVER_PORT};

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'online',
    message: '🦏 Rhino Node.js Server is healthy and running',
    timestamp: new Date().toISOString()
  }));
});

server.listen(port, '0.0.0.0', () => {
  console.log(\`[rhino] Node.js server listening on http://0.0.0.0:\${port}\`);
});
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Created starter HTTP service in ${MAIN_FILE}."
fi

# Run npm install or bun install if package.json has dependencies
if [ "${AUTO_INSTALL}" = "true" ] || [ "${AUTO_INSTALL}" = "1" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Installing project dependencies..."
    if command -v bun &>/dev/null; then
        bun install
    elif command -v npm &>/dev/null; then
        npm install --omit=dev
    fi
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Node.js application setup completed successfully."
