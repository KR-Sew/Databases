#!/usr/bin/env bash
set -Eeuo pipefail
# MongoDB Atlas CLI installer/updater for Debian/Ubuntu
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info(){ printf '%b[INFO]%b %s\n' "$CYAN" "$NC" "$*"; }
ok(){ printf '%b[ OK ]%b %s\n' "$GREEN" "$NC" "$*"; }
warn(){ printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$*" >&2; }
fail(){ printf '%b[FAIL]%b %s\n' "$RED" "$NC" "$*" >&2; exit 1; }
trap 'printf "[FAIL] Line %s: %s (exit %s)\n" "$LINENO" "$BASH_COMMAND" "$?" >&2' ERR
MODE=install; PARSER=jq
usage(){ cat <<'HELP'
Usage: install_mongoAtlas.sh [--check] [-jq|-awk] [--help]
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
case "$ARCH" in amd64) PKG_ARCH=x86_64;; arm64) PKG_ARCH=arm64;; *) fail "Unsupported architecture: $ARCH";; esac
info "OS: $PRETTY_NAME | Architecture: $ARCH | Mode: $MODE | Parser: $PARSER"
if [[ "$MODE" == install ]]; then
  (( EUID == 0 )) || fail 'Installation requires sudo/root'
  info 'Installing dependencies...'
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget ca-certificates tar "$PARSER" 
else
  command -v curl >/dev/null || fail 'curl is required for --check'
  command -v "$PARSER" >/dev/null || fail "$PARSER is required for --check (install it separately)"
fi
installed=''
if command -v atlas >/dev/null 2>&1; then
  installed=$(atlas --version 2>/dev/null | head -n1 || true)
  [[ -n "$installed" ]] && info "Installed: $installed" || warn 'Atlas CLI found but version could not be determined'
else warn 'Atlas CLI is not installed'; fi
info 'Reading latest GitHub release metadata...'
API=https://api.github.com/repos/mongodb/mongodb-atlas-cli/releases/latest
RELEASE_JSON=$(curl -fsSL --connect-timeout 10 --max-time 30 "$API")
if [[ "$PARSER" == jq ]]; then
  RAW_TAG=$(jq -r '.tag_name // empty' <<< "$RELEASE_JSON")
else
  RAW_TAG=$(printf '%s\n' "$RELEASE_JSON" | awk -F'"' '/"tag_name"[[:space:]]*:/ {print $4; exit}')
fi
[[ -n "$RAW_TAG" ]] || fail 'GitHub response lacks a release tag'
LATEST_VERSION=${RAW_TAG#atlascli/}; LATEST_VERSION=${LATEST_VERSION#v}
[[ "$LATEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || fail "Unexpected tag: $RAW_TAG"
info "Raw tag: $RAW_TAG"; info "Latest version: $LATEST_VERSION"
if [[ -n "$installed" ]] && [[ "$installed" == *"$LATEST_VERSION"* ]]; then ok 'Installed version matches latest release'; [[ "$MODE" == check ]] && exit 0; else [[ "$MODE" == check ]] && { info 'Update available or Atlas CLI not installed'; exit 0; }; fi
ASSET_NAME="mongodb-atlas-cli_${LATEST_VERSION}_linux_${PKG_ARCH}.tar.gz"
if [[ "$PARSER" == jq ]]; then
  DOWNLOAD_URL=$(jq -r --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .browser_download_url' <<< "$RELEASE_JSON")
else
  # GitHub API emits name and browser_download_url on separate lines in each asset object.
  DOWNLOAD_URL=$(printf '%s\n' "$RELEASE_JSON" | awk -v target="$ASSET_NAME" '
    /"assets"[[:space:]]*:/ {assets=1}
    assets && /"browser_download_url"[[:space:]]*:/ {u=$0; sub(/^.*"browser_download_url"[[:space:]]*:[[:space:]]*"/,"",u); sub(/".*$/, "",u)}
    assets && /"name"[[:space:]]*:/ {n=$0; sub(/^.*"name"[[:space:]]*:[[:space:]]*"/,"",n); sub(/".*$/, "",n); if(n==target) {print u; exit}}
  ')
fi
[[ -n "$DOWNLOAD_URL" ]] || fail "Asset not found: $ASSET_NAME (inspect release assets on GitHub)"
TMP_DIR=$(mktemp -d /tmp/mongodb-atlas-cli.XXXXXX)
trap 'rm -rf -- "$TMP_DIR"' EXIT
ARCHIVE_FILE="$TMP_DIR/$ASSET_NAME"
info "Downloading: $DOWNLOAD_URL"
curl -fL --retry 3 --connect-timeout 10 -o "$ARCHIVE_FILE" "$DOWNLOAD_URL"
info 'Checking archive integrity...'
tar -tzf "$ARCHIVE_FILE" >/dev/null || fail 'Archive is corrupt'
INSTALL_DIR=/opt/mongodb-atlas-cli
STAGE_DIR=$(mktemp -d /opt/.mongodb-atlas-cli.XXXXXX)
trap 'rm -rf -- "$TMP_DIR" "$STAGE_DIR"' EXIT
tar -xzf "$ARCHIVE_FILE" -C "$STAGE_DIR" --no-same-owner
ATLAS_BIN=$(find "$STAGE_DIR" -type f -name atlas -print -quit)
[[ -n "$ATLAS_BIN" ]] || fail 'Atlas executable not found in archive'
chmod +x "$ATLAS_BIN"
"$ATLAS_BIN" --version >/dev/null 2>&1 || fail 'Downloaded Atlas executable failed validation'
# Preserve previous installation until the new binary has been validated.
BACKUP_DIR=''
if [[ -e "$INSTALL_DIR" ]]; then BACKUP_DIR="${INSTALL_DIR}.previous"; rm -rf -- "$BACKUP_DIR"; mv "$INSTALL_DIR" "$BACKUP_DIR"; fi
mv "$STAGE_DIR" "$INSTALL_DIR"
NEW_BIN="${ATLAS_BIN/#$STAGE_DIR/$INSTALL_DIR}"
ln -sfn "$NEW_BIN" /usr/local/bin/atlas
hash -r
NEW_VERSION=$(/usr/local/bin/atlas --version 2>/dev/null | head -n1 || true)
[[ -n "$NEW_VERSION" ]] || fail 'Atlas CLI failed post-install validation'
ok "Atlas CLI installed: $NEW_VERSION"
info "Binary: $NEW_BIN"
# Atlas CLI configuration is user-specific, not system-wide.
TARGET_USER=${SUDO_USER:-}
if [[ -n "$TARGET_USER" && "$TARGET_USER" != root ]] && command -v runuser >/dev/null 2>&1; then
  info "Applying Atlas CLI preference for user: $TARGET_USER"
  if CONFIG_OUTPUT=$(runuser -u "$TARGET_USER" -- /usr/local/bin/atlas config set silence_storage_warning true 2>&1); then
    ok "Atlas storage warning preference applied for $TARGET_USER"
  else
    warn "Could not set Atlas preference for $TARGET_USER: $CONFIG_OUTPUT"
  fi
else
  info 'Skipping per-user Atlas configuration (run with sudo from a regular user to apply it)'
fi
ok 'Completed.'
