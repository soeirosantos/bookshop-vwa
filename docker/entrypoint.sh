#!/bin/bash
set -euo pipefail

STATE=/var/lib/bookshop
MARKER="$STATE/.initialized"

hash_for() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

rand_hex() {
  od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
}

if [[ ! -f "$MARKER" ]]; then
  mkdir -p "$STATE" /srv/bookshop/app /srv/bookshop/uploads /var/www/.ssh

  if [[ -n "${BOOKSHOP_SEED:-}" ]]; then
    base="$(hash_for "bookshop:${BOOKSHOP_SEED}")"
    users=(ledger catalog release publisher operator)
    idx=$((16#${base:0:2} % ${#users[@]}))
    LAB_USER="${users[$idx]}"
    LAB_PASS="Bk!${base:2:16}x7"
    USER_FLAG="user{$(hash_for "user:${BOOKSHOP_SEED}" | cut -c1-24)}"
    ROOT_FLAG="root{$(hash_for "root:${BOOKSHOP_SEED}" | cut -c1-24)}"
    DIAG_PORT=$((8800 + (16#${base:18:4} % 401)))
  else
    entropy="$(rand_hex)"
    users=(ledger catalog release publisher operator)
    idx=$((16#${entropy:0:2} % ${#users[@]}))
    LAB_USER="${users[$idx]}"
    LAB_PASS="Bk!$(rand_hex | cut -c1-16)x7"
    USER_FLAG="user{$(rand_hex | cut -c1-24)}"
    ROOT_FLAG="root{$(rand_hex | cut -c1-24)}"
    DIAG_PORT=$((8800 + (16#${entropy:2:4} % 401)))
  fi

  if ! getent group bookops >/dev/null; then
    groupadd bookops
  fi
  if ! id "$LAB_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G bookops "$LAB_USER"
  fi
  echo "$LAB_USER:$LAB_PASS" | chpasswd

  printf '%s\n' "$USER_FLAG" > "/home/$LAB_USER/user.txt"
  chown "$LAB_USER:$LAB_USER" "/home/$LAB_USER/user.txt"
  chmod 0600 "/home/$LAB_USER/user.txt"

  printf '%s\n' "$ROOT_FLAG" > /root/root.txt
  chmod 0600 /root/root.txt

  # Writable by the ordinary operations user, consumed by the root backup job.
  chown root:bookops /srv/bookshop/uploads
  chmod 2775 /srv/bookshop/uploads
  printf 'Quarterly catalog export\n' > /srv/bookshop/uploads/catalog.txt
  chown root:bookops /srv/bookshop/uploads/catalog.txt
  chmod 0664 /srv/bookshop/uploads/catalog.txt

  # Build a small application repository with a credential accidentally committed
  # in history and removed in the current tree.
  cp -a /opt/bookshop/app/repo-template/. /srv/bookshop/app/
  cd /srv/bookshop/app
  git init -q
  git config user.email "release-bot@bookshop.local"
  git config user.name "Bookshop Release Bot"

  cat > .deploy-notes <<DEPLOY
legacy_deploy_user=$LAB_USER
legacy_deploy_password=$LAB_PASS
note=temporary credential for the catalog migration; remove before release
DEPLOY
  git add .
  git commit -q -m "prepare catalog migration"

  rm -f .deploy-notes
  cat > .env <<'DECOY'
DB_HOST=db.internal
DB_USER=bookshop_app
DB_PASSWORD=Summer2019-Deprecated
ADMIN_API_KEY=disabled-legacy-key
DECOY
  git add -A
  git commit -q -m "remove migration notes and rotate application config"

  # Allow the web-service account to inspect deployed application files/history,
  # but not modify the repository.
  chown -R root:www-data /srv/bookshop/app
  chmod -R g+rX,o-rwx /srv/bookshop/app
  git config --system --add safe.directory /srv/bookshop/app

  # SSH policy: password auth is enabled for the lab user; root SSH is disabled.
  cat >> /etc/ssh/sshd_config <<SSHCONF
PasswordAuthentication yes
PermitRootLogin no
AllowUsers $LAB_USER
UsePAM yes
SSHCONF

  cat > "$STATE/runtime.env" <<RUNTIME
LAB_USER=$LAB_USER
LAB_PASS=$LAB_PASS
DIAG_PORT=$DIAG_PORT
RUNTIME
  chmod 0600 "$STATE/runtime.env"

  cat > /root/operator-answer-key.txt <<ANSWER
Bookshop VWA runtime answer key
===============================
Seed: ${BOOKSHOP_SEED:-<random>}
Lab user: $LAB_USER
Lab password: $LAB_PASS
Internal diagnostics port: $DIAG_PORT
User flag: $USER_FLAG
Root flag: $ROOT_FLAG

Intended high-level path (operator spoiler):
public URL fetcher -> loopback diagnostics -> command execution as www-data ->
Git history -> SSH as ordinary user -> root backup wildcard weakness -> root
ANSWER
  chmod 0600 /root/operator-answer-key.txt

  touch "$MARKER"
fi

# Export runtime data so supervised services receive the generated diagnostics port.
# shellcheck disable=SC1090
source "$STATE/runtime.env"
export LAB_USER LAB_PASS DIAG_PORT

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/bookshop.conf
