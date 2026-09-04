#!/bin/bash

# Config
DB_NAME="hospital_meddb"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5433"

# Timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# File path
BACKUP_FILE="database/backups/${DB_NAME}_$TIMESTAMP.sql"

echo "Backing up database..."

pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME > $BACKUP_FILE

if [ $? -eq 0 ]; then
  echo "Backup successful ✅"
  echo "Saved at: $BACKUP_FILE"
else
  echo "Backup failed ❌"
fi