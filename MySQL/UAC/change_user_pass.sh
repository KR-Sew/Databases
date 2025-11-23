#!/bin/bash

# Script to change MySQL user password on Debian

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if MySQL is installed
if ! command -v mysql &> /dev/null; then
    echo "MySQL not found. Please install MySQL first."
    exit 1
fi

# Prompt for MySQL root user
read -p "Enter MySQL root username (default: root): " mysql_root
mysql_root=${mysql_root:-root}

# Prompt for MySQL root password
read -s -p "Enter MySQL root password: " mysql_root_pass
echo

# Test MySQL connection
if ! mysql -u "$mysql_root" -p"$mysql_root_pass" -e "SELECT 1" &> /dev/null; then
    echo "MySQL connection failed. Please check root credentials."
    exit 1
fi

# Prompt for user to change password
read -p "Enter the MySQL username to change password for: " mysql_user

# Check if user exists
if ! mysql -u "$mysql_root" -p"$mysql_root_pass" -e "SELECT User FROM mysql.user WHERE User='$mysql_user';" | grep -q "$mysql_user"; then
    echo "User $mysql_user does not exist."
    exit 1
fi

# Prompt for new password
read -s -p "Enter new password for $mysql_user: " new_pass
echo
read -s -p "Confirm new password: " new_pass_confirm
echo

# Verify passwords match
if [ "$new_pass" != "$new_pass_confirm" ]; then
    echo "Passwords do not match."
    exit 1
fi

# Change password
mysql -u "$mysql_root" -p"$mysql_root_pass" -e "ALTER USER '$mysql_user'@'localhost' IDENTIFIED BY '$new_pass'; FLUSH PRIVILEGES;"

if [ $? -eq 0 ]; then
    echo "Password for $mysql_user changed successfully."
else
    echo "Failed to change password."
    exit 1
fi