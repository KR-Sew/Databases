#!/usr/bin/env bash
set -Eeuo pipefail

MYSQL_SERVICE="${MYSQL_SERVICE:-mysql}"
MYSQL_DATADIR="${MYSQL_DATADIR:-/var/lib/mysql}"
MYSQL_CNF="${MYSQL_CNF:-/etc/mysql/mysql.conf.d/mysqld.cnf}"
BACKUP_DIR="${BACKUP_DIR:-/root/mysql-rescue}"
DUMP_FILE="${DUMP_FILE:-$BACKUP_DIR/mysql-recovery-$(date +%F-%H%M%S).sql.gz}"

DO_REBUILD="false"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)][INFO] $*"; }
ok()  { echo "[$(ts)][OK] $*"; }
err() { echo "[$(ts)][ERROR] $*" >&2; }

usage() {
  cat <<EOF
Usage:
  sudo $0 [--rebuild-after-dump]

Default:
  Try innodb_force_recovery levels 1..6.
  If MySQL starts, dump all databases and stop.

Optional:
  --rebuild-after-dump
      After successful dump, move broken datadir, initialize clean MySQL,
      remove recovery option, start MySQL, and restore dump.
EOF
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Run as root: sudo $0"
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild-after-dump)
      DO_REBUILD="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

set_recovery_level() {
  local level="$1"

  log "Setting innodb_force_recovery=$level in $MYSQL_CNF"

  cp -a "$MYSQL_CNF" "$MYSQL_CNF.bak.$(date +%F-%H%M%S)"

  if grep -qE '^[[:space:]]*innodb_force_recovery[[:space:]]*=' "$MYSQL_CNF"; then
    sed -i -E "s|^[[:space:]]*innodb_force_recovery[[:space:]]*=.*|innodb_force_recovery=$level|" "$MYSQL_CNF"
  else
    awk -v level="$level" '
      BEGIN { added=0 }
      /^\[mysqld\]/ {
        print
        print "innodb_force_recovery=" level
        added=1
        next
      }
      { print }
      END {
        if (added == 0) {
          print ""
          print "[mysqld]"
          print "innodb_force_recovery=" level
        }
      }
    ' "$MYSQL_CNF" > "$MYSQL_CNF.tmp"

    mv "$MYSQL_CNF.tmp" "$MYSQL_CNF"
  fi
}

remove_recovery_option() {
  log "Removing innodb_force_recovery from $MYSQL_CNF"
  cp -a "$MYSQL_CNF" "$MYSQL_CNF.bak.remove-recovery.$(date +%F-%H%M%S)"
  sed -i -E '/^[[:space:]]*innodb_force_recovery[[:space:]]*=/d' "$MYSQL_CNF"
}

mysql_is_running() {
  systemctl is-active --quiet "$MYSQL_SERVICE"
}

dump_all_databases() {
  mkdir -p "$BACKUP_DIR"

  log "Dumping all databases to: $DUMP_FILE"
  log "Using --skip-lock-tables because recovery mode can make normal locking unsafe"

  mysqldump \
    --all-databases \
    --quick \
    --skip-lock-tables \
    --routines \
    --events \
    --triggers \
    | gzip > "$DUMP_FILE"

  if [[ ! -s "$DUMP_FILE" ]]; then
    err "Dump file is empty or missing: $DUMP_FILE"
    exit 1
  fi

  ok "Dump completed: $DUMP_FILE"
  ls -lh "$DUMP_FILE"
}

make_raw_backup_before_rebuild() {
  local raw_backup="$BACKUP_DIR/mysql-datadir-before-rebuild-$(date +%F-%H%M%S).tar"

  log "Stopping MySQL before raw backup"
  systemctl stop "$MYSQL_SERVICE" || true

  log "Creating raw datadir backup before rebuild: $raw_backup"
  tar --xattrs --acls -cpf "$raw_backup" "$MYSQL_DATADIR"

  ok "Raw backup completed: $raw_backup"
}

initialize_clean_datadir() {
  local broken_dir="$MYSQL_DATADIR.broken.$(date +%F-%H%M%S)"

  log "Moving broken datadir to: $broken_dir"
  mv "$MYSQL_DATADIR" "$broken_dir"

  log "Creating fresh datadir: $MYSQL_DATADIR"
  install -d -o mysql -g mysql -m 750 "$MYSQL_DATADIR"

  log "Initializing clean MySQL datadir"
  mysqld --initialize-insecure --user=mysql

  ok "Clean datadir initialized"
}

restore_dump() {
  log "Starting MySQL clean instance"
  systemctl start "$MYSQL_SERVICE"

  log "Testing MySQL connection"
  mysql -e "SELECT VERSION();"

  log "Restoring dump: $DUMP_FILE"
  gunzip -c "$DUMP_FILE" | mysql

  ok "Restore completed"
}

require_root

mkdir -p "$BACKUP_DIR"

log "Stopping MySQL before recovery attempts"
systemctl stop "$MYSQL_SERVICE" || true

SUCCESS_LEVEL=""

for level in 1 2 3 4 5 6; do
  set_recovery_level "$level"

  log "Trying to start MySQL with innodb_force_recovery=$level"
  if systemctl start "$MYSQL_SERVICE"; then
    sleep 3

    if mysql_is_running; then
      SUCCESS_LEVEL="$level"
      ok "MySQL started successfully with innodb_force_recovery=$level"
      break
    fi
  fi

  err "MySQL failed with innodb_force_recovery=$level"
  journalctl -u "$MYSQL_SERVICE" -n 30 --no-pager || true
  systemctl stop "$MYSQL_SERVICE" || true
done

if [[ -z "$SUCCESS_LEVEL" ]]; then
  err "MySQL did not start with recovery levels 1..6"
  exit 1
fi

dump_all_databases

if [[ "$DO_REBUILD" != "true" ]]; then
  ok "Dump is ready."
  log "MySQL is still running in recovery mode level $SUCCESS_LEVEL."
  log "Recommended next step:"
  echo "sudo $0 --rebuild-after-dump"
  exit 0
fi

make_raw_backup_before_rebuild
remove_recovery_option
initialize_clean_datadir
restore_dump

ok "All done. MySQL was rebuilt and dump restored."
ok "Check databases with: sudo mysql -e 'SHOW DATABASES;'"