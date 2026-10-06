#!/usr/bin/env bash
set -Eeuo pipefail

PG_MAJOR="${PG_MAJOR:-18}"
PG_CLUSTER="${PG_CLUSTER:-main}"
PG_UNIT="postgresql@${PG_MAJOR}-${PG_CLUSTER}"
PSQL=(sudo -u postgres psql -X -At)

info() { printf '\n[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }

info "Cluster status"
pg_lsclusters

if systemctl is-active --quiet "$PG_UNIT"; then
    ok "$PG_UNIT is active."
else
    warn "$PG_UNIT is not active."
fi

info "PostgreSQL version"
"${PSQL[@]}" -c "SELECT version();" || true

info "Network listeners"
ss -lntp | grep ':5432' || warn "No TCP/5432 listener found."

info "Relevant PostgreSQL settings"
sudo -u postgres psql -X -c "
SELECT name, setting
FROM pg_settings
WHERE name IN (
  'listen_addresses',
  'port',
  'password_encryption',
  'ssl',
  'ssl_cert_file',
  'ssl_key_file'
)
ORDER BY name;
" || true

cert="$("${PSQL[@]}" -c "SHOW ssl_cert_file;" 2>/dev/null || true)"
if [[ -n "$cert" && -r "$cert" ]]; then
    info "Server certificate"
    openssl x509 -in "$cert" -noout \
        -subject -issuer -dates -ext subjectAltName
else
    warn "Could not read configured server certificate: ${cert:-unknown}"
fi

info "pg_hba.conf parse errors"
errors="$(
sudo -u postgres psql -X -At -c "
SELECT coalesce(line_number::text,'?') || ': ' || error
FROM pg_hba_file_rules
WHERE error IS NOT NULL;
" 2>/dev/null || true
)"
if [[ -z "$errors" ]]; then
    ok "No pg_hba.conf parse errors."
else
    printf '%s\n' "$errors"
fi
