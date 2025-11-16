#!/bin/bash

# Simple Database Backup with .env
# simple-backup-env.sh

set -e

# Default .env file location
ENV_FILE="$(dirname "$0")/.mysql_backup.env"

# Load .env file
if [[ -f "$ENV_FILE" ]]; then
    echo "Loading configuration from: $ENV_FILE"
    source "$ENV_FILE"
else
    echo "Error: .env file not found: $ENV_FILE"
    echo "Create a .env file with MYSQL_USER, MYSQL_PASSWORD, etc."
    exit 1
fi

# Set defaults
BACKUP_DIR="${BACKUP_DIR:-/var/backups/mysql}"
COMPRESSION="${COMPRESSION:-gzip}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
mkdir -p "$BACKUP_PATH"

# Set MySQL password for commands
export MYSQL_PWD="$MYSQL_PASSWORD"

echo "Starting backup of databases to: $BACKUP_PATH"

# Get list of databases (exclude system databases)
DATABASES=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -e "SHOW DATABASES;" | grep -v -E "(Database|information_schema|performance_schema|mysql|sys)")

# Backup each database
for DB in $DATABASES; do
    echo "Backing up: $DB"
    mysqldump -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" --routines --events --triggers "$DB" > "$BACKUP_PATH/${DB}.sql"
    
    # Compress
    case $COMPRESSION in
        gzip)
            gzip "$BACKUP_PATH/${DB}.sql"
            ;;
        bzip2)
            bzip2 "$BACKUP_PATH/${DB}.sql"
            ;;
        xz)
            xz "$BACKUP_PATH/${DB}.sql"
            ;;
    esac
done

# Cleanup old backups
find "$BACKUP_DIR" -type d -name "2*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true

echo "Backup completed: $BACKUP_PATH"
echo "Total size: $(du -sh "$BACKUP_PATH" | cut -f1)"