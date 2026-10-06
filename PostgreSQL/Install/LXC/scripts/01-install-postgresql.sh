#!/usr/bin/env bash
set -Eeuo pipefail

PG_MAJOR="${PG_MAJOR:-18}"

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
die()  { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run this script as root or with sudo."
[[ -r /etc/os-release ]] || die "/etc/os-release not found."

. /etc/os-release
[[ "${ID:-}" == "debian" ]] || die "This How-To targets Debian."
info "Detected ${PRETTY_NAME:-Debian}."

info "Installing PGDG prerequisites..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl gnupg postgresql-common

if [[ ! -f /etc/apt/sources.list.d/pgdg.list ]]; then
    info "Configuring the PostgreSQL PGDG repository..."
    /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
else
    ok "PGDG repository already configured."
fi

apt-get update

info "Candidate package:"
apt-cache policy "postgresql-${PG_MAJOR}" | sed -n '1,8p'

info "Installing PostgreSQL ${PG_MAJOR}..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    "postgresql-${PG_MAJOR}" \
    "postgresql-client-${PG_MAJOR}"

ok "Installation complete."
pg_lsclusters

info "Password encryption:"
sudo -u postgres psql -Atc "SHOW password_encryption;"

info "Current listeners:"
ss -lntp | grep ':5432' || true
