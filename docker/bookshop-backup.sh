#!/bin/sh
set -eu

BACKUP_DIR=/srv/bookshop/uploads
OUT=/var/backups/bookshop-uploads.tgz

mkdir -p /var/backups
cd "$BACKUP_DIR"

# Intentionally simplistic legacy backup implementation for the lab.
# The root-owned script itself is not writable by the application user.
tar -czf "$OUT" * 2>/dev/null || true
