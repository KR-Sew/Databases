#!/usr/bin/env bash
set -Eeuo pipefail

MYSQL_DATADIR="${MYSQL_DATADIR:-/var/lib/mysql}"
BACKUP_DIR="${BACKUP_DIR:-/root/mysql-rescue}"
MYSQL_SERVICE="${MYSQL_SERVICE:-mysql}"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)][INFO] $*"; }
ok()  { echo "[$(ts)][OK] $*"; }
err() { echo "[$(ts)][ERROR] $*" >&2; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Run as root: sudo $0"
    exit 1
  fi
}

require_root

mkdir -p "$BACKUP_DIR"

log "Stopping MySQL service: $MYSQL_SERVICE"
systemctl stop "$MYSQL_SERVICE" || true

log "Checking filesystem space"
df -h "$MYSQL_DATADIR" | tee "$BACKUP_DIR/df-$(date +%F-%H%M%S).log"

log "Checking recent kernel/storage/filesystem errors"
dmesg | grep -Ei 'ext4|xfs|nvme|sda|error|corrupt|i/o|fail' \
  | tee "$BACKUP_DIR/dmesg-storage-$(date +%F-%H%M%S).log" || true

log "Inspecting MySQL datadir"
ls -lah "$MYSQL_DATADIR" | tee "$BACKUP_DIR/datadir-list-$(date +%F-%H%M%S).log"

log "Inspecting old-style redo files: #ib_redo*"
find "$MYSQL_DATADIR" -maxdepth 1 -name '#ib_redo*' -ls \
  | tee "$BACKUP_DIR/old-redo-list-$(date +%F-%H%M%S).log" || true

if [[ -d "$MYSQL_DATADIR/#innodb_redo" ]]; then
  log "Inspecting MySQL 8 dynamic redo directory: #innodb_redo"
  ls -lah "$MYSQL_DATADIR/#innodb_redo" \
    | tee "$BACKUP_DIR/innodb-redo-list-$(date +%F-%H%M%S).log"
else
  log "No #innodb_redo directory found"
fi

BACKUP_FILE="$BACKUP_DIR/mysql-datadir-raw-$(date +%F-%H%M%S).tar"

log "Creating raw datadir backup: $BACKUP_FILE"
tar --xattrs --acls -cpf "$BACKUP_FILE" "$MYSQL_DATADIR"

ok "Backup completed: $BACKUP_FILE"
ok "Step 1 finished"