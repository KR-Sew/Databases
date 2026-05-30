#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
# Install-MongoShell.sh
#
# Install or update MongoDB Shell (mongosh)
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
TMP_DIR="/tmp/mongosh-install"
mkdir -p "$TMP_DIR"

ARCH="$(dpkg --print-architecture)"

case "$ARCH" in
    amd64)
        PKG_ARCH="x64"
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
    ca-certificates


# ---------- Current Version ----------
if command -v mongosh >/dev/null 2>&1; then
    CURRENT_VERSION="$(mongosh --version)"
    log_info "Installed version: $CURRENT_VERSION"
else
    log_warn "mongosh is not installed."
fi

# ---------- Detect Latest Version ----------
log_info "Detecting latest mongosh version from GitHub..."

LATEST_VERSION="$(
    curl -fsSL https://api.github.com/repos/mongodb-js/mongosh/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"v([^"]+)".*/\1/'
)"

if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Unable to detect latest mongosh version."
    exit 1
fi

log_info "Latest version: $LATEST_VERSION"


ARCHIVE_FILE="$TMP_DIR/mongosh-${LATEST_VERSION}-linux-${PKG_ARCH}.tgz"

DOWNLOAD_URL="https://github.com/mongodb-js/mongosh/releases/download/v${LATEST_VERSION}/mongosh-${LATEST_VERSION}-linux-${PKG_ARCH}.tgz"

log_info "Downloading package..."
log_info "$DOWNLOAD_URL"

if ! wget --spider -q "$DOWNLOAD_URL"; then
    log_error "Package URL is unavailable."
    exit 1
fi

wget -q --show-progress \
    -O "$ARCHIVE_FILE" \
    "$DOWNLOAD_URL"

# ---------- Install ----------

log_info "Installing mongosh..."

INSTALL_DIR="/opt/mongosh"
BIN_LINK="/usr/local/bin/mongosh"

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

tar -xzf "$ARCHIVE_FILE" -C "$INSTALL_DIR"

# ---------- Detect extracted root directory ----------

EXTRACTED_ROOT="$(find "$INSTALL_DIR" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    | head -n1)"

if [[ -z "$EXTRACTED_ROOT" ]]; then
    log_error "Unable to detect extracted mongosh directory."
    exit 1
fi

log_info "Detected extracted directory:"
log_info "$EXTRACTED_ROOT"

# ---------- Detect mongosh binary ----------

MONGOSH_BIN="$(find "$EXTRACTED_ROOT" \
    -type f \
    -name mongosh \
    | head -n1)"

if [[ -z "$MONGOSH_BIN" ]]; then
    log_error "mongosh binary not found."
    exit 1
fi

log_info "Detected mongosh binary:"
log_info "$MONGOSH_BIN"

chmod +x "$MONGOSH_BIN"

# ---------- Create Symlink ----------

ln -sf "$MONGOSH_BIN" "$BIN_LINK"

# ---------- Validation ----------

if command -v mongosh >/dev/null 2>&1; then

    NEW_VERSION="$(mongosh --version)"

    log_ok "mongosh installed successfully."
    log_info "Current version: $NEW_VERSION"

else
    log_error "mongosh installation failed."
    exit 1
fi