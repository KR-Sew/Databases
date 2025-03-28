#!/bin/bash
# Function to display usage
usage() {
  echo "Usage: $0 -d <database_name> -c <compression> -p <backup_path>"
  echo "  -d <database_name>   Name of the database to back up"
  echo "  -c <compression>     Compression type (e.g., gzip)"
  echo "  -p <backup_path>     Path to the backup folder"
  exit 1
}
# Parse command line arguments
while getopts "d:c:p:" opt; do
  case ${opt} in
    d )
      DB_NAME=$OPTARG
      ;;
    c )
      COMPRESSION=$OPTARG
      ;;
    p )
      BACKUP_PATH=$OPTARG
      ;;
    * )
      usage
      ;;
  esac
done
# Check if all parameters are provided
if [ -z "$DB_NAME" ] || [ -z "$COMPRESSION" ] || [ -z "$BACKUP_PATH" ]; then
  usage
fi
# Create the backup folder if it doesn't exist
mkdir -p "$BACKUP_PATH"
# Construct the mongodump command
MONGODUMP_CMD="mongodump --db=$DB_NAME --out=$BACKUP_PATH"
# Add compression option if specified
if [ "$COMPRESSION" == "gzip" ]; then
  MONGODUMP_CMD+=" --gzip"
fi
# Execute the mongodump command
echo "Running backup command: $MONGODUMP_CMD"
$MONGODUMP_CMD
echo "Backup completed successfully."