#!/usr/bin/env bash
set -euo pipefail

docker compose exec -T -u root bookshop cat /root/operator-answer-key.txt
