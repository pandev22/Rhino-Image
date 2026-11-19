#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Bun Ultra-Fast JavaScript/TypeScript Runtime
# Prepares Bun project, installs dependencies, and creates starter HTTP service
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

MAIN_FILE="${MAIN_FILE:-index.ts}"
AUTO_INSTALL="${AUTO_INSTALL:-true}"
SERVER_PORT="${SERVER_PORT:-3000}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Bun application in ${TARGET_DIR}..."

# If package.json doesn't exist, create starter template
if [ ! -f "package.json" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Creating baseline package.json and ${MAIN_FILE}..."
    cat <<EOF > package.json
{
  "name": "rhino-bun-app",
  "module": "${MAIN_FILE}",
  "type": "module",
  "scripts": {
    "start": "bun run ${MAIN_FILE}",
    "dev": "bun --watch ${MAIN_FILE}"
  },
  "devDependencies": {
    "@types/bun": "latest"
  }
}
EOF

    cat <<EOF > "${MAIN_FILE}"
const port = Number(process.env.SERVER_PORT || ${SERVER_PORT});

console.log(\`[rhino] 🦏 Starting Bun server on port \${port}...\`);

Bun.serve({
  port,
  fetch(req) {
    const url = new URL(req.url);
    return new Response(JSON.stringify({
      status: "online",
      engine: \`Bun \${Bun.version}\`,
      path: url.pathname,
      message: "🦏 Rhino Bun Server is ready and high-performance",
      timestamp: new Date().toISOString()
    }), {
      headers: { "Content-Type": "application/json" }
    });
  },
});

console.log(\`[rhino] Bun server ready at http://0.0.0.0:\${port}\`);
EOF
    echo -e "\e[1;32m[rhino-installer]\e[0m Created high-performance Bun starter in ${MAIN_FILE}."
fi

# Run bun install
if [ "${AUTO_INSTALL}" = "true" ] || [ "${AUTO_INSTALL}" = "1" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Running bun install..."
    bun install
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Bun application installation completed successfully."
