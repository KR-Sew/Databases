#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -v <Volume Group> -l <Logical Volume> -s <Snapshot Name>"
    echo "Example: $0 -v vg0 -l lv0 -s lv0_snapshot"
    exit 1
}

# Parse command line arguments
while getopts "v:l:s:" opt; do
  case ${opt} in
    v ) VG_NAME="$OPTARG" ;;
    l ) LV_NAME="$OPTARG" ;;
    s ) SNAPSHOT_NAME="$OPTARG" ;;
    \? ) usage ;;
  esac
done

# Check if the necessary parameters are provided
if [ -z "$VG_NAME" ] || [ -z "$LV_NAME" ] || [ -z "$SNAPSHOT_NAME" ]; then
    usage
fi

# Check if the Logical Volume exists
lvdisplay /dev/$VG_NAME/$LV_NAME &>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Logical Volume '$LV_NAME' does not exist in Volume Group '$VG_NAME'."
    exit 1
fi

# Create the snapshot
echo "Creating snapshot of Logical Volume '$LV_NAME' in Volume Group '$VG_NAME'..."
lvcreate --size 1G --snapshot --name "$SNAPSHOT_NAME" "/dev/$VG_NAME/$LV_NAME"

# Check if the snapshot creation was successful
if [ $? -eq 0 ]; then
    echo "Snapshot '$SNAPSHOT_NAME' created successfully!"
else
    echo "Snapshot creation failed."
    exit 1
fi
