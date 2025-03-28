#!/bin/bash

# Default values
DB_NAME=""
BACKUP_DIR="/var/backups"
COMPRESS="gzip"

# Usage function
usage() {
    echo "Usage: $0 -d <database_name> [-b <backup_folder>] [-c <compression_type>]"
    echo "  -d  Database name (required)"
    echo "  -b  Backup folder (default: /var/backups)"
    echo "  -c  Compression type: gzip (default), bzip2, xz, none"
    exit 1
}

# Parse command-line arguments
while getopts ":d:b:c:" opt; do
    case ${opt} in
        d ) DB_NAME=$OPTARG ;;
        b ) BACKUP_DIR=$OPTARG ;;
        c ) COMPRESS=$OPTARG ;;
        * ) usage ;;
    esac
done

# Validate required arguments
if [[ -z "$DB_NAME" ]]; then
    echo "Error: Database name is required."
    usage
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Create timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"

# Perform database dump
mysqldump -u root -p "$DB_NAME" > "$BACKUP_FILE"

# Compress backup if needed
case $COMPRESS in
    gzip)
        gzip "$BACKUP_FILE"
        BACKUP_FILE+=".gz"
        ;;
    bzip2)
        bzip2 "$BACKUP_FILE"
        BACKUP_FILE+=".bz2"
        ;;
    xz)
        xz "$BACKUP_FILE"
        BACKUP_FILE+=".xz"
        ;;
    none)
        echo "No compression applied."
        ;;
    *)
        echo "Invalid compression type. Using gzip by default."
        gzip "$BACKUP_FILE"
        BACKUP_FILE+=".gz"
        ;;
esac

# Output result
echo "Backup completed: $BACKUP_FILE"
