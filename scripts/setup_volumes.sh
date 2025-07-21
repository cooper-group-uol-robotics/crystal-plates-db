#!/bin/bash

# Setup script for Crystal Plates DB named Docker volumes
# This script helps you migrate existing data and set up persistent named volumes

set -e

echo "🔧 Setting up Crystal Plates DB persistent volumes..."

# Check if volumes already exist
STORAGE_EXISTS=$(docker volume ls -q | grep "crystal_plates_db_storage" || true)
DB_EXISTS=$(docker volume ls -q | grep "crystal_plates_db_database" || true)

echo "📊 Current volume status:"
echo "  Storage volume exists: ${STORAGE_EXISTS:-"No"}"
echo "  Database volume exists: ${DB_EXISTS:-"No"}"

# Create volumes if they don't exist
if [ -z "$STORAGE_EXISTS" ]; then
    echo "📁 Creating storage volume..."
    docker volume create crystal_plates_db_storage
else
    echo "✅ Storage volume already exists"
fi

if [ -z "$DB_EXISTS" ]; then
    echo "🗄️  Creating database volume..."
    docker volume create crystal_plates_db_database
else
    echo "✅ Database volume already exists"
fi

# Check if we have a running container to migrate data from
CONTAINER_ID=$(docker ps -q --filter "name=crystal-plates-db" || true)

if [ -n "$CONTAINER_ID" ]; then
    echo "🔄 Found running container: $CONTAINER_ID"
    echo "   Checking for existing data to migrate..."
    
    # Check if container has database files
    DB_FILES=$(docker exec $CONTAINER_ID find /rails/db -name "*.sqlite3" -type f 2>/dev/null || true)
    STORAGE_FILES=$(docker exec $CONTAINER_ID find /rails/storage -type f 2>/dev/null | head -5 || true)
    
    if [ -n "$DB_FILES" ]; then
        echo "📋 Found database files in container:"
        echo "$DB_FILES"
        
        read -p "🤔 Do you want to copy existing database files to the persistent volume? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "📦 Copying database files to volume..."
            docker run --rm \
                --volumes-from $CONTAINER_ID \
                -v crystal_plates_db_database:/backup_target \
                alpine sh -c "cp -r /rails/db/* /backup_target/ 2>/dev/null || true"
            echo "✅ Database files copied"
        fi
    fi
    
    if [ -n "$STORAGE_FILES" ]; then
        echo "📋 Found storage files in container"
        
        read -p "🤔 Do you want to copy existing storage files to the persistent volume? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "📦 Copying storage files to volume..."
            docker run --rm \
                --volumes-from $CONTAINER_ID \
                -v crystal_plates_db_storage:/backup_target \
                alpine sh -c "cp -r /rails/storage/* /backup_target/ 2>/dev/null || true"
            echo "✅ Storage files copied"
        fi
    fi
fi

# Show volume information
echo ""
echo "📋 Volume Information:"
echo "🗄️  Database volume:"
docker volume inspect crystal_plates_db_database --format "   Location: {{.Mountpoint}}"

echo "📁 Storage volume:"
docker volume inspect crystal_plates_db_storage --format "   Location: {{.Mountpoint}}"

echo ""
echo "✅ Setup complete!"
echo ""
echo "🚀 Next steps:"
echo "   1. Stop your current container: docker stop crystal-plates-db"
echo "   2. Remove the old container: docker rm crystal-plates-db"  
echo "   3. Deploy with Kamal: bin/kamal deploy"
echo ""
echo "💾 Your data will now persist across container rebuilds!"
echo "🔍 To inspect volume contents:"
echo "   Database: docker run --rm -v crystal_plates_db_database:/data alpine ls -la /data"
echo "   Storage:  docker run --rm -v crystal_plates_db_storage:/data alpine ls -la /data"
