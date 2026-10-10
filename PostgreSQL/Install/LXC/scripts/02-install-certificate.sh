#!/usr/bin/env bash
set -Eeuo pipefail

CERT_SRC="${1:-}"
KEY_SRC="${2:-}"
SSL_DIR="${SSL_DIR:-/etc/postgresql/ssl}"
CERT_DST="${SSL_DIR}/server.crt"
KEY_DST="${SSL_DIR}/server.key"
PG_UNIT="${PG_UNIT:-postgresql@18-main}"

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
die()  { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run this script as root or with sudo."
[[ -n "$CERT_SRC" && -n "$KEY_SRC" ]] || {
    echo "Usage: $0 /path/to/public.pem /path/to/private.pem"
    exit 2
}
[[ -r "$CERT_SRC" ]] || die "Certificate not readable: $CERT_SRC"
[[ -r "$KEY_SRC" ]] || die "Private key not readable: $KEY_SRC"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

info "Checking certificate identity..."
openssl x509 -in "$CERT_SRC" -noout -subject -issuer -dates -ext subjectAltName

cert_hash="$(
    openssl x509 -in "$CERT_SRC" -pubkey -noout |
    openssl pkey -pubin -outform DER 2>/dev/null |
    sha256sum | awk '{print $1}'
)"
key_hash="$(
    openssl pkey -in "$KEY_SRC" -pubout -outform DER 2>/dev/null |
    sha256sum | awk '{print $1}'
)"

[[ -n "$cert_hash" && "$cert_hash" == "$key_hash" ]] ||
    die "Certificate and private key do not match."

ok "Certificate and private key match."

cert_count="$(grep -c 'BEGIN CERTIFICATE' "$CERT_SRC" || true)"
info "PEM contains ${cert_count} certificate(s)."

install -d -o root -g postgres -m 0750 "$SSL_DIR"
install -o postgres -g postgres -m 0644 "$CERT_SRC" "$CERT_DST"
install -o postgres -g postgres -m 0600 "$KEY_SRC" "$KEY_DST"

sudo -u postgres test -r "$CERT_DST" ||
    die "postgres cannot read $CERT_DST"
sudo -u postgres test -r "$KEY_DST" ||
    die "postgres cannot read $KEY_DST"

ok "Certificate installed at $CERT_DST"
ok "Private key installed at $KEY_DST"

info "Restarting ${PG_UNIT}..."
systemctl restart "$PG_UNIT"
systemctl is-active --quiet "$PG_UNIT" ||
    die "${PG_UNIT} did not start."

ok "${PG_UNIT} is running."
pg_lsclusters
