#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Catch errors in piped commands
set -u  # Treat unset variables as an error

# Define constants
MONGO_VERSION="8.0"
MONGO_KEYRING="/usr/share/keyrings/mongodb-server-${MONGO_VERSION}.gpg"
MONGO_LIST="/etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list"
MONGO_REPO="http://repo.mongodb.org/apt/debian"
DEBIAN_CODENAME=$(lsb_release -sc)

echo "Starting MongoDB ${MONGO_VERSION} installation on Debian ${DEBIAN_CODENAME}..."

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Update package list and install dependencies
echo "Updating package list..."
apt-get update -qq

echo "Installing required packages (gnupg, curl)..."
apt-get install -y -qq gnupg curl

# Import MongoDB public GPG key
echo "Adding MongoDB GPG key..."
if curl -fsSL "https://www.mongodb.org/static/pgp/server-${MONGO_VERSION}.asc" | gpg --dearmor -o "${MONGO_KEYRING}"; then
    echo "GPG key added successfully."
else
    echo "Failed to add GPG key. Exiting."
    exit 1
fi

# Create the MongoDB APT source list
echo "Configuring MongoDB APT repository..."
echo "deb [signed-by=${MONGO_KEYRING}] ${MONGO_REPO} ${DEBIAN_CODENAME}/mongodb-org/${MONGO_VERSION} main" | tee "${MONGO_LIST}"

# Update package list again after adding MongoDB repo
echo "Updating package list after adding MongoDB repository..."
apt-get update -qq

# Install MongoDB
echo "Installing MongoDB ${MONGO_VERSION}..."
apt-get install -y -qq mongodb-org

# Start and enable MongoDB
echo "Starting and enabling MongoDB service..."
systemctl start mongod
systemctl enable mongod

# Check MongoDB service status
echo "Checking MongoDB service status..."
if systemctl is-active --quiet mongod; then
    echo "✅ MongoDB is running."
else
    echo "❌ MongoDB failed to start. Checking logs..."
    journalctl -u mongod --no-pager --lines=20
    exit 1
fi

echo "MongoDB ${MONGO_VERSION} installation completed successfully."
