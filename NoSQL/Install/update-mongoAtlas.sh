#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
# Install-MongoAtlasCLI.sh
#
# Install or update MongoDB Atlas CLI
# Debian / Ubuntu
# =========================================================

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------- Logging ----------
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[ OK ]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ---------- Root Check ----------
if [[ $EUID -ne 0 ]]; then
    log_error "Run this script as root."
    exit 1
fi

# ---------- Variables ----------
TMP_DIR="/tmp/mongodb-atlas-cli-install"
INSTALL_DIR="/opt/mongodb-atlas-cli"
BIN_LINK="/usr/local/bin/atlas"

mkdir -p "$TMP_DIR"

ARCH="$(dpkg --print-architecture)"

case "$ARCH" in
    amd64)
        PKG_ARCH="x86_64"
        ;;
    arm64)
        PKG_ARCH="arm64"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# ---------- Dependencies ----------
log_info "Installing dependencies..."

apt-get update -qq

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    ca-certificates \
    tar \
    jq

# ---------- Current Version ----------
if command -v atlas >/dev/null 2>&1; then
    CURRENT_VERSION="$(atlas version 2>/dev/null | head -n1 || true)"
    log_info "Installed version: $CURRENT_VERSION"
else
    log_warn "MongoDB Atlas CLI is not installed."
fi

# ---------- Detect Latest Version ----------
log_info "Detecting latest Atlas CLI version from GitHub..."

RELEASE_API="https://api.github.com/repos/mongodb/mongodb-atlas-cli/releases/latest"

RELEASE_JSON="$(curl -fsSL \
    --connect-timeout 10 \
    --max-time 30 \
    "$RELEASE_API")"

RAW_TAG="$(jq -r '.tag_name // empty' <<< "$RELEASE_JSON")"

if [[ -z "$RAW_TAG" ]]; then
    log_error "Unable to detect latest release tag."
    exit 1
fi

# Support:
#   atlascli/v1.55.0
#   v1.59.1
#   1.59.1

LATEST_VERSION="${RAW_TAG#atlascli/}"
LATEST_VERSION="${LATEST_VERSION#v}"

if [[ ! "$LATEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Unexpected release version: $LATEST_VERSION"
    exit 1
fi

log_info "Raw tag        : $RAW_TAG"
log_info "Latest version : $LATEST_VERSION"

# ---------- Find Release Asset ----------
ASSET_NAME="mongodb-atlas-cli_${LATEST_VERSION}_linux_${PKG_ARCH}.tar.gz"

log_info "Searching GitHub release assets..."
log_info "Expected asset: $ASSET_NAME"

DOWNLOAD_URL="$(
    jq -r --arg name "$ASSET_NAME" \
        '.assets[]
         | select(.name == $name)
         | .browser_download_url' \
        <<< "$RELEASE_JSON"
)"

if [[ -z "$DOWNLOAD_URL" ]]; then
    log_error "No matching Linux archive found in this release."

    log_info "Available Linux archives:"

    jq -r '
        .assets[]
        | select(.name | test("linux.*tar.gz$"))
        | "  " + .name
    ' <<< "$RELEASE_JSON"

    exit 1
fi

log_ok "Matching release asset found."

# ---------- Download ----------
ARCHIVE_FILE="$TMP_DIR/$ASSET_NAME"

log_info "Downloading Atlas CLI..."
log_info "$DOWNLOAD_URL"

wget --tries=3 \
    --timeout=30 \
    --show-progress \
    -O "$ARCHIVE_FILE" \
    "$DOWNLOAD_URL"

if [[ ! -s "$ARCHIVE_FILE" ]]; then
    log_error "Downloaded archive is empty."
    exit 1
fi

log_ok "Download completed."

# ---------- Verify Archive ----------
log_info "Checking archive integrity..."

if tar -tzf "$ARCHIVE_FILE" >/dev/null; then
    log_ok "Archive structure is valid."
else
    log_error "Downloaded archive is invalid."
    exit 1
fi


wget -q --show-progress \
    -O "$ARCHIVE_FILE" \
    "$DOWNLOAD_URL"

# ---------- Install ----------
log_info "Installing MongoDB Atlas CLI..."

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

tar -xzf "$ARCHIVE_FILE" -C "$INSTALL_DIR"

ATLAS_BIN="$(find "$INSTALL_DIR" -type f -name atlas | head -n1)"

if [[ -z "$ATLAS_BIN" ]]; then
    log_error "Atlas binary not found."
    exit 1
fi

chmod +x "$ATLAS_BIN"

ln -sf "$ATLAS_BIN" "$BIN_LINK"

# ---------- Configure Atlas CLI ----------

log_info "Applying Atlas CLI post-install configuration..."

CONFIG_OUTPUT="$(
    atlas config set silence_storage_warning true 2>&1
)" || CONFIG_EXIT=$?

CONFIG_EXIT="${CONFIG_EXIT:-0}"

if [[ "$CONFIG_EXIT" -eq 0 ]]; then

    log_ok "Atlas CLI storage warning successfully suppressed."

else

    log_warn "Atlas CLI configuration returned non-zero exit code."
    log_warn "Output:"
    echo "$CONFIG_OUTPUT"

fi

# ---------- Validation ----------

if command -v atlas >/dev/null 2>&1; then

    NEW_VERSION="$(atlas --version 2>/dev/null | head -n1 || true)"

    log_ok "MongoDB Atlas CLI installed successfully."
    log_info "Current version: $NEW_VERSION"

else
    log_error "MongoDB Atlas CLI installation failed."
    exit 1
fi

# ---------- Cleanup ----------

rm -rf "$TMP_DIR"

log_ok "Completed."