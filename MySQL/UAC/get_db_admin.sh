#!/bin/bash
# get_db_admin.sh
# Shows users with privileges on a given database (typically admin/root-like)

set -euo pipefail

# --- Configuration ---
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_HOST="${MYSQL_HOST:-localhost}"

# --- Prompt for database ---
read -p "Enter database name: " DB_NAME
[[ -z "$DB_NAME" ]] && { echo "Database name required."; exit 1; }

# --- Prompt for password ---
read -s -p "Enter MySQL password for ${MYSQL_USER}@${MYSQL_HOST}: " MYSQL_PASS
echo

# --- Verify connection ---
if ! mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h"$MYSQL_HOST" -e "USE \`$DB_NAME\`;" >/dev/null 2>&1; then
    echo "ERROR: Cannot access database '$DB_NAME'. Check name or privileges." >&2
    exit 1
fi

# --- Query privileged users ---
echo "Users with privileges on database '$DB_NAME':"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h"$MYSQL_HOST" -Nse "
SELECT DISTINCT Grantee
FROM information_schema.SCHEMA_PRIVILEGES
WHERE TABLE_SCHEMA = '$DB_NAME'
  AND PRIVILEGE_TYPE IN ('ALL PRIVILEGES', 'CREATE', 'DROP', 'ALTER')
UNION
SELECT DISTINCT User
FROM mysql.db
WHERE Db = '$DB_NAME' AND Select_priv = 'Y';
"