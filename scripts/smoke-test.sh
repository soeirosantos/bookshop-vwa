#!/usr/bin/env bash
set -euo pipefail
WEB_PORT="${WEB_PORT:-18080}"
SSH_PORT="${SSH_PORT:-12222}"

printf 'Web health: '
curl -fsS "http://127.0.0.1:${WEB_PORT}/health"
printf '\nSSH banner: '
(timeout 2 bash -c "exec 3<>/dev/tcp/127.0.0.1/${SSH_PORT}; head -n1 <&3") || true
printf '\n'
