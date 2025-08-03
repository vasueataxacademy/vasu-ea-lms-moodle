#!/bin/bash

# Moodle Production Backup Script
# Run this script regularly via cron for automated backups

set -e

# Configuration
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="moodle_backup_${DATE}"
RETENTION_DAYS=7

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Create backup directory
mkdir -p ${BACKUP_DIR}

echo "Starting Moodle backup: ${BACKUP_NAME}"

# 1. Database backup
echo "Backing up database..."
docker exec mariadb mariadb-dump \
    -u root \
    -p${MARIADB_ROOT_PASSWORD} \
    --single-transaction \
    --routines \
    --triggers \
    ${MARIADB_DATABASE} > ${BACKUP_DIR}/${BACKUP_NAME}_database.sql

# 2. Moodle files backup
echo "Backing up Moodle files..."
tar -czf ${BACKUP_DIR}/${BACKUP_NAME}_moodle.tar.gz \
    -C ./data moodle moodledata

# 3. Redis backup (if needed)
echo "Backing up Redis data..."
docker exec redis redis-cli -a ${REDIS_PASSWORD} --rdb /tmp/dump.rdb
docker cp redis:/tmp/dump.rdb ${BACKUP_DIR}/${BACKUP_NAME}_redis.rdb

# 4. Configuration backup
echo "Backing up configuration..."
tar -czf ${BACKUP_DIR}/${BACKUP_NAME}_config.tar.gz \
    docker-compose.yml .env nginx/

# 5. Create backup manifest
echo "Creating backup manifest..."
cat > ${BACKUP_DIR}/${BACKUP_NAME}_manifest.txt << EOF
Backup Date: $(date)
Database: ${BACKUP_NAME}_database.sql
Moodle Files: ${BACKUP_NAME}_moodle.tar.gz
Redis Data: ${BACKUP_NAME}_redis.rdb
Configuration: ${BACKUP_NAME}_config.tar.gz
EOF

# 6. Cleanup old backups
echo "Cleaning up old backups (older than ${RETENTION_DAYS} days)..."
find ${BACKUP_DIR} -name "moodle_backup_*" -mtime +${RETENTION_DAYS} -delete

echo "Backup completed successfully: ${BACKUP_NAME}"
echo "Backup location: ${BACKUP_DIR}"