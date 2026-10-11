#!/usr/bin/env bash
set -Eeuo pipefail
# MongoDB Shell installer/updater for Debian/Ubuntu
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info(){ printf '%b[INFO]%b %s\n' "$CYAN" "$NC" "$*"; }
ok(){ printf '%b[ OK ]%b %s\n' "$GREEN" "$NC" "$*"; }
warn(){ printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*" >&2; }
fail(){ printf '%b[FAIL]%b %s\n' "$RED" "$NC" "$*" >&2; exit 1; }
trap 'printf "[FAIL] Line %s: %s (exit %s)\n" "$LINENO" "$BASH_COMMAND" "$?" >&2' ERR
MODE=install; PARSER=jq
usage(){ cat <<'HELP'
Usage: install_mongoShell.sh [--check] [-jq|-awk] [--help]
  --check  Compare installed version with latest GitHub release; no changes
  -jq      Parse GitHub API with jq (default)
  -awk     Parse GitHub API with awk
HELP
}
for arg in "$@"; do case "$arg" in --check) MODE=check;; -jq) PARSER=jq;; -awk) PARSER=awk;; -h|--help) usage; exit 0;; *) fail "Unknown argument: $arg";; esac; done
[[ -r /etc/os-release ]] || fail 'Cannot detect operating system'
. /etc/os-release
[[ "$ID" == debian || "$ID" == ubuntu ]] || fail "Unsupported OS: $ID"
ARCH=$(dpkg --print-architecture)
case "$ARCH" in amd64) PKG_ARCH=x64;; arm64) PKG_ARCH=arm64;; *) fail "Unsupported architecture: $ARCH";; esac
info "OS: $PRETTY_NAME | Architecture: $ARCH | Mode: $MODE | Parser: $PARSER"
if [[ "$MODE" == install ]]; then
  (( EUID == 0 )) || fail 'Installation requires sudo/root'
  info 'Installing dependencies...'
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates tar "$PARSER"
else
  command -v curl >/dev/null || fail 'curl is required for --check'
  command -v "$PARSER" >/dev/null || fail "$PARSER is required for --check"
fi
installed=''
if command -v mongosh >/dev/null 2>&1; then
  installed=$(mongosh --version 2>/dev/null | head -n1 || true)
  [[ -n "$installed" ]] && info "Installed version: $installed" || warn 'mongosh exists but version could not be determined'
else warn 'mongosh is not installed'; fi
info 'Reading latest mongosh GitHub release...'
RELEASE_JSON=$(curl -fsSL --connect-timeout 10 --max-time 30 https://api.github.com/repos/mongodb-js/mongosh/releases/latest)
if [[ "$PARSER" == jq ]]; then RAW_TAG=$(jq -r '.tag_name // empty' <<< "$RELEASE_JSON"); else RAW_TAG=$(printf '%s\n' "$RELEASE_JSON" | awk -F'"' '/"tag_name"[[:space:]]*:/ {print $4; exit}'); fi
[[ -n "$RAW_TAG" ]] || fail 'Missing release tag'
LATEST_VERSION=${RAW_TAG#v}
[[ "$LATEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || fail "Unexpected tag: $RAW_TAG"
info "Raw tag: $RAW_TAG"; info "Latest version: $LATEST_VERSION"
if [[ "$installed" == "$LATEST_VERSION" ]]; then ok 'Already up to date'; exit 0; fi
if [[ "$MODE" == check ]]; then info 'Update available or mongosh not installed'; exit 0; fi
ASSET_NAME="mongosh-${LATEST_VERSION}-linux-${PKG_ARCH}.tgz"
if [[ "$PARSER" == jq ]]; then
  DOWNLOAD_URL=$(jq -r --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .browser_download_url' <<< "$RELEASE_JSON")
else
  DOWNLOAD_URL=$(printf '%s\n' "$RELEASE_JSON" | awk -v target="$ASSET_NAME" '
    /"assets"[[:space:]]*:/ {assets=1}
    assets && /"browser_download_url"[[:space:]]*:/ {u=$0; sub(/^.*"browser_download_url"[[:space:]]*:[[:space:]]*"/,"",u); sub(/".*$/, "",u)}
    assets && /"name"[[:space:]]*:/ {n=$0; sub(/^.*"name"[[:space:]]*:[[:space:]]*"/,"",n); sub(/".*$/, "",n); if(n==target) {print u; exit}}
  ')
fi
[[ -n "$DOWNLOAD_URL" ]] || fail "Asset not found: $ASSET_NAME"
TMP_DIR=$(mktemp -d /tmp/mongosh.XXXXXX)
trap 'rm -rf -- "$TMP_DIR"' EXIT
info "Downloading: $DOWNLOAD_URL"
curl -fL --retry 3 --connect-timeout 10 -o "$TMP_DIR/$ASSET_NAME" "$DOWNLOAD_URL"
tar -tzf "$TMP_DIR/$ASSET_NAME" >/dev/null || fail 'Archive invalid'
STAGE_DIR=$(mktemp -d /opt/.mongosh.XXXXXX)
trap 'rm -rf -- "$TMP_DIR" "$STAGE_DIR"' EXIT
tar -xzf "$TMP_DIR/$ASSET_NAME" -C "$STAGE_DIR" --no-same-owner
BIN=$(find "$STAGE_DIR" -type f -name mongosh -print -quit)
[[ -n "$BIN" ]] || fail 'mongosh binary not found'
chmod +x "$BIN"
"$BIN" --version >/dev/null 2>&1 || fail 'Downloaded binary failed validation'
INSTALL_DIR=/opt/mongosh
if [[ -e "$INSTALL_DIR" ]]; then rm -rf -- "${INSTALL_DIR}.previous"; mv "$INSTALL_DIR" "${INSTALL_DIR}.previous"; fi
mv "$STAGE_DIR" "$INSTALL_DIR"
NEW_BIN="${BIN/#$STAGE_DIR/$INSTALL_DIR}"
ln -sfn "$NEW_BIN" /usr/local/bin/mongosh
hash -r
NEW_VERSION=$(/usr/local/bin/mongosh --version)
ok "mongosh installed: $NEW_VERSION"
info "Binary: $NEW_BIN"
ok 'Completed.'
