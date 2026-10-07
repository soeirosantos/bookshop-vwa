#!/usr/bin/env bash
set -euo pipefail

docker compose down --remove-orphans

docker compose up -d --build

echo "Fresh Bookshop VWA instance started."
echo "Web: http://127.0.0.1:${WEB_PORT:-18080}"
echo "SSH: 127.0.0.1:${SSH_PORT:-12222}"
