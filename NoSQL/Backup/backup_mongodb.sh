#!/bin/bash

set -e  # Exit immediately on error
set -o pipefail  # Catch errors in piped commands
set -u  # Treat unset variables as an error

# Function to display usage
usage() {
  echo "Usage: $0 -d <database_name> -c <compression> -p <backup_path>"
  echo "  -d <database_name>   Name of the database to back up"
  echo "  -c <compression>     Compression type (gzip or none)"
  echo "  -p <backup_path>     Path to the backup folder"
  exit 1
}

# Parse command line arguments
DB_NAME=""
COMPRESSION=""
BACKUP_PATH=""

while getopts "d:c:p:" opt; do
  case ${opt} in
    d ) DB_NAME="$OPTARG" ;;
    c ) COMPRESSION="$OPTARG" ;;
    p ) BACKUP_PATH="$OPTARG" ;;
    * ) usage ;;
  esac
done

# Validate input parameters
if [[ -z "$DB_NAME" || -z "$COMPRESSION" || -z "$BACKUP_PATH" ]]; then
  echo "❌ Error: Missing required arguments."
  usage
fi

if [[ "$COMPRESSION" != "gzip" && "$COMPRESSION" != "none" ]]; then
  echo "❌ Error: Invalid compression type. Use 'gzip' or 'none'."
  usage
fi

# Create the backup folder if it doesn't exist
mkdir -p "$BACKUP_PATH"

# Construct the mongodump command
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_PATH/${DB_NAME}_backup_$TIMESTAMP"
MONGODUMP_CMD="mongodump --db=$DB_NAME --out=$BACKUP_DIR"

# Add compression option if specified
if [[ "$COMPRESSION" == "gzip" ]]; then
  MONGODUMP_CMD+=" --gzip"
fi

# Execute the mongodump command
echo "🔄 Running backup command: $MONGODUMP_CMD"
if eval "$MONGODUMP_CMD"; then
  echo "✅ Backup completed successfully."
else
  echo "❌ Backup failed!"
  exit 1
fi

# Display backup details
echo "📂 Backup saved at: $BACKUP_DIR"
exit 0
