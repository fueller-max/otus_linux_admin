#!/bin/bash

# Path to the directory you want to back up
SOURCE_DIR="/tmp/data"

# Borg repository URL
REPO_URL="borg@192.168.56.160:/var/backup/"

# Backup name using date
BACKUP_NAME="backup-$(date +"%Y-%m-%d_%H:%M:%S")"

# Passphrase
export BORG_PASSPHRASE="Otus1234"

# Perform the backup
borg create --stats  "$REPO_URL::$BACKUP_NAME" "$SOURCE_DIR"

# Check consistency of repo
borg check "$REPO_URL"

# Clean up old backups
borg prune  --list   --keep-daily 90   "$REPO_URL"

# Clean up the space
borg compact "$REPO_URL"



