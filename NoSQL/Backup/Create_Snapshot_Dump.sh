#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -u <MongoDB URI> -d <Database Name> -o <Output Directory>"
    echo "Example: $0 -u mongodb+srv://<username>:<password>@cluster0.mongodb.net -d myDatabase -o /path/to/backup"
    exit 1
}

# Parse command line arguments
while getopts "u:d:o:" opt; do
  case ${opt} in
    u ) MONGO_URI="$OPTARG" ;;
    d ) DATABASE="$OPTARG" ;;
    o ) OUTPUT_DIR="$OPTARG" ;;
    \? ) usage ;;
  esac
done

# Check if the necessary parameters are provided
if [ -z "$MONGO_URI" ] || [ -z "$DATABASE" ] || [ -z "$OUTPUT_DIR" ]; then
    usage
fi

# Ensure the output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory '$OUTPUT_DIR' does not exist."
    exit 1
fi

# Generate the snapshot file name with a timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SNAPSHOT_FILE="${OUTPUT_DIR}/mongodb_snapshot_${DATABASE}_${TIMESTAMP}"

# Perform the snapshot using mongodump
echo "Creating snapshot of database '$DATABASE' at '$SNAPSHOT_FILE'..."
mongodump --uri="$MONGO_URI" --db="$DATABASE" --out="$SNAPSHOT_FILE"

# Check if the snapshot was successful
if [ $? -eq 0 ]; then
    echo "Snapshot created successfully!"
else
    echo "Snapshot creation failed."
    exit 1
fi
