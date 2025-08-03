#!/bin/bash

# Moodle Production Restore Script
# Usage: ./restore.sh BACKUP_NAME

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 BACKUP_NAME"
    echo "Example: $0 moodle_backup_20240122_143000"
    exit 1
fi

BACKUP_NAME=$1
BACKUP_DIR="./backups"

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "Starting Moodle restore from: ${BACKUP_NAME}"

# Verify backup files exist
if [ ! -f "${BACKUP_DIR}/${BACKUP_NAME}_database.sql" ]; then
    echo "Error: Database backup file not found"
    exit 1
fi

if [ ! -f "${BACKUP_DIR}/${BACKUP_NAME}_moodle.tar.gz" ]; then
    echo "Error: Moodle files backup not found"
    exit 1
fi

# Stop services
echo "Stopping services..."
docker-compose down

# 1. Restore database
echo "Restoring database..."
docker-compose up -d mariadb
sleep 30  # Wait for MariaDB to start

docker exec -i mariadb mariadb \
    -u root \
    -p${MARIADB_ROOT_PASSWORD} \
    ${MARIADB_DATABASE} < ${BACKUP_DIR}/${BACKUP_NAME}_database.sql

# 2. Restore Moodle files
echo "Restoring Moodle files..."
rm -rf ./data/moodle ./data/moodledata
tar -xzf ${BACKUP_DIR}/${BACKUP_NAME}_moodle.tar.gz -C ./data/

# 3. Restore Redis data (if exists)
if [ -f "${BACKUP_DIR}/${BACKUP_NAME}_redis.rdb" ]; then
    echo "Restoring Redis data..."
    cp ${BACKUP_DIR}/${BACKUP_NAME}_redis.rdb ./data/redis/dump.rdb
fi

# 4. Start all services
echo "Starting all services..."
docker-compose up -d

echo "Restore completed successfully!"
echo "Please verify your Moodle installation is working correctly."