#!/usr/bin/env bash
set -euo pipefail

docker compose exec -T -u root bookshop bash -lc '
set -e
source /var/lib/bookshop/runtime.env
printf "lab_user=%s\n" "$LAB_USER"
printf "diag_port=%s\n" "$DIAG_PORT"
id "$LAB_USER"
test -r "/home/$LAB_USER/user.txt"
test -r /root/root.txt
test -d /srv/bookshop/app/.git
test -w /srv/bookshop/uploads || true
printf "cron="; cat /etc/cron.d/bookshop-backup
'
