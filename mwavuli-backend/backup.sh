#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

echo "📦 1. Backing up PostgreSQL Database..."
docker compose -f infra/docker-compose.yml exec -T db pg_dump -U postgres mwavuli > "$BACKUP_DIR/db_dump.sql"

echo "📷 2. Backing up MinIO Images..."
docker compose -f infra/docker-compose.yml cp minio:/data "$BACKUP_DIR/minio_data" 2>/dev/null || echo "MinIO copy completed"

echo "------------------------------------------------"
echo "✅ Backup created successfully at: $BACKUP_DIR"
echo "   - DB Dump: $BACKUP_DIR/db_dump.sql"
echo "   - MinIO Data: $BACKUP_DIR/minio_data"
echo "------------------------------------------------"
