#!/usr/bin/env bash
# ==============================================================================
# Rhino Installer - Python App, API & Discord Bot Runtime
# Sets up virtual environment (.venv), installs requirements.txt, and creates starter
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME_DIR:-/home/container}"
cd "${TARGET_DIR}"

MAIN_FILE="${MAIN_FILE:-main.py}"
CREATE_VENV="${CREATE_VENV:-true}"
SERVER_PORT="${SERVER_PORT:-8000}"

echo -e "\e[1;33m[rhino-installer]\e[0m Setting up Python environment in ${TARGET_DIR}..."

# Setup isolated Python virtual environment
if [ "${CREATE_VENV}" = "true" ] || [ "${CREATE_VENV}" = "1" ]; then
    if [ ! -d ".venv" ]; then
        echo -e "\e[1;33m[rhino-installer]\e[0m Creating Python virtualenv in .venv..."
        python3 -m venv .venv
    fi
    PIP_BIN=".venv/bin/pip"
    PYTHON_BIN=".venv/bin/python3"
else
    PIP_BIN="pip3"
    PYTHON_BIN="python3"
fi

# Baseline starter script if none exists
if [ ! -f "${MAIN_FILE}" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Generating baseline ${MAIN_FILE}..."
    cat <<EOF > "${MAIN_FILE}"
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from datetime import datetime

port = int(os.environ.get("SERVER_PORT", "${SERVER_PORT}"))

class RhinoHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        payload = {
            "status": "online",
            "runtime": f"Python {sys.version.split()[0]}",
            "message": "🦏 Rhino Python Server is ready and listening",
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        self.wfile.write(json.dumps(payload, indent=2).encode("utf-8"))

    def log_message(self, format, *args):
        print(f"[rhino-python] {self.address_string()} - {format % args}")

if __name__ == "__main__":
    server_address = ("0.0.0.0", port)
    httpd = HTTPServer(server_address, RhinoHandler)
    print(f"[rhino] Python server listening on http://0.0.0.0:{port}")
    httpd.serve_forever()
EOF
fi

if [ ! -f "requirements.txt" ]; then
    cat <<EOF > requirements.txt
# Add your pip dependencies here
EOF
fi

# Install dependencies if requirements.txt has content
if [ -s "requirements.txt" ]; then
    echo -e "\e[1;33m[rhino-installer]\e[0m Installing pip dependencies from requirements.txt..."
    "${PIP_BIN}" install --upgrade pip
    "${PIP_BIN}" install -r requirements.txt
fi

echo -e "\e[1;32m[rhino-installer]\e[0m Python environment setup completed successfully."
