#!/bin/bash

# Backup script for Crystal Plates DB volumes
# Creates timestamped backups of both database and storage volumes

set -e

BACKUP_DIR="/tmp/crystal_plates_backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "🔄 Creating backup of Crystal Plates DB volumes..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database volume
echo "🗄️  Backing up database volume..."
docker run --rm \
    -v crystal_plates_db_database:/source:ro \
    -v "$BACKUP_DIR":/backup \
    alpine tar czf "/backup/database_${TIMESTAMP}.tar.gz" -C /source .

# Backup storage volume  
echo "📁 Backing up storage volume..."
docker run --rm \
    -v crystal_plates_db_storage:/source:ro \
    -v "$BACKUP_DIR":/backup \
    alpine tar czf "/backup/storage_${TIMESTAMP}.tar.gz" -C /source .

echo "✅ Backup complete!"
echo "📁 Backup files created:"
echo "   Database: $BACKUP_DIR/database_${TIMESTAMP}.tar.gz"
echo "   Storage:  $BACKUP_DIR/storage_${TIMESTAMP}.tar.gz"

# Show backup sizes
echo ""
echo "📊 Backup sizes:"
ls -lh "$BACKUP_DIR"/*_${TIMESTAMP}.tar.gz

echo ""
echo "💡 To restore a backup:"
echo "   Database: docker run --rm -v crystal_plates_db_database:/target -v $BACKUP_DIR:/backup alpine tar xzf /backup/database_${TIMESTAMP}.tar.gz -C /target"
echo "   Storage:  docker run --rm -v crystal_plates_db_storage:/target -v $BACKUP_DIR:/backup alpine tar xzf /backup/storage_${TIMESTAMP}.tar.gz -C /target"
