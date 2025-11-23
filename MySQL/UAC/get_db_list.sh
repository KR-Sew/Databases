#!/bin/bash
# list_mysql_databases.sh
# Lists all databases visible to the connected MySQL user

set -euo pipefail

# --- Configuration (edit if needed) ---
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_HOST="${MYSQL_HOST:-localhost}"

# --- Prompt for password securely ---
read -s -p "Enter MySQL password for ${MYSQL_USER}@${MYSQL_HOST}: " MYSQL_PASS
echo

# --- Check connection ---
if ! mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h"$MYSQL_HOST" -e "SELECT 1;" >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to MySQL. Check credentials/host." >&2
    exit 1
fi

# --- List databases ---
echo "Available databases:"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h"$MYSQL_HOST" \
      -Nse "SHOW DATABASES;" | grep -vE '^(information_schema|performance_schema|mysql|sys)$'