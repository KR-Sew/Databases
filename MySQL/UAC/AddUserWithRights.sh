#!/bin/bash

# Default values
DB_NAME=""
DB_USER=""
DB_HOST="localhost"
PRIVILEGES="ALL PRIVILEGES"

# Usage function
usage() {
    echo "Usage: $0 -u <username> -d <database_name> [-h <host>] [-p <privileges>]"
    echo "  -u  MySQL username (required)"
    echo "  -d  Database name (required)"
    echo "  -h  Hostname (default: localhost)"
    echo "  -p  Privileges (default: ALL PRIVILEGES)"
    exit 1
}

# Parse command-line arguments
while getopts ":u:d:h:p:" opt; do
    case ${opt} in
        u ) DB_USER=$OPTARG ;;
        d ) DB_NAME=$OPTARG ;;
        h ) DB_HOST=$OPTARG ;;
        p ) PRIVILEGES=$OPTARG ;;
        * ) usage ;;
    esac
done

# Validate required arguments
if [[ -z "$DB_USER" || -z "$DB_NAME" ]]; then
    echo "Error: Username and database name are required."
    usage
fi

# Securely prompt for password
read -s -p "Enter password for new user: " DB_PASS
echo
read -s -p "Confirm password: " DB_PASS_CONFIRM
echo

if [[ "$DB_PASS" != "$DB_PASS_CONFIRM" ]]; then
    echo "Error: Passwords do not match."
    exit 1
fi

# Create user and grant privileges
MYSQL_COMMAND="CREATE USER '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';
GRANT $PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$DB_HOST';
FLUSH PRIVILEGES;"

# Execute MySQL command
mysql -u root -p -e "$MYSQL_COMMAND"

if [[ $? -eq 0 ]]; then
    echo "User '$DB_USER' successfully created and granted access to '$DB_NAME'"
else
    echo "Error: Failed to create user or set privileges."
fi
