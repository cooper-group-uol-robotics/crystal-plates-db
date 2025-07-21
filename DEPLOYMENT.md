# Crystal Plates DB - Deployment Guide

This guide covers how to deploy the Crystal Plates DB application from a Git repository using Kamal.

## Prerequisites

- **Server**: Linux server with Docker installed
- **Domain**: Domain name pointing to your server (optional but recommended)
- **Git**: Access to this repository
- **Ruby**: Ruby 3.3.0+ installed locally (for running Kamal commands)

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/crystal-plates-db.git
cd crystal-plates-db
```

### 2. Install Dependencies

```bash
# Install Ruby gems
bundle install

# Make scripts executable
chmod +x scripts/setup_volumes.sh
```

### 3. Configure Deployment

Copy and edit the deployment configuration:

```bash
# Copy example configuration (if it exists)
cp config/deploy.example.yml config/deploy.yml

# Edit the deployment configuration
nano config/deploy.yml
```

**Required changes in `config/deploy.yml`:**

```yaml
# Update these values:
service: crystal_plates_db
image: your-dockerhub-username/crystal_plates_db

servers:
  web:
    - your-server-ip-address  # Replace with your server IP

proxy:
  ssl: true
  host: your-domain.com      # Replace with your domain

registry:
  username: your-dockerhub-username  # Replace with your Docker Hub username
```

### 4. Set Up Secrets

Create the secrets file:

```bash
# Create secrets directory
mkdir -p .kamal

# Create secrets file
nano .kamal/secrets
```

Add your secrets:

```bash
# .kamal/secrets
KAMAL_REGISTRY_PASSWORD=your-dockerhub-token
RAILS_MASTER_KEY=your-rails-master-key
```

**To get your Rails master key:**
```bash
cat config/master.key
```

## Volume Setup (One-time)

The application uses persistent Docker volumes for data storage. Run this once on your server:

```bash
# Set up persistent volumes and migrate existing data (if any)
./scripts/setup_volumes.sh
```

This script will:
- Create named Docker volumes for database and file storage
- Migrate any existing data from running containers
- Show you volume locations and next steps

## Deployment

### First Deployment

```bash
# Build and deploy the application
bin/kamal deploy
```

This will:
1. Build the Docker image
2. Push it to your registry
3. Deploy to your server
4. Set up SSL certificates (if domain is configured)
5. Start the application

### Subsequent Deployments

```bash
# Deploy updates
bin/kamal deploy

# Or just update the app without rebuilding
bin/kamal app deploy
```

## Data Persistence

The application is configured with persistent named Docker volumes:

- **Database**: `crystal_plates_db_database` → `/rails/db`
- **Storage**: `crystal_plates_db_storage` → `/rails/storage`

These volumes persist across deployments and container rebuilds.

## Useful Commands

```bash
# Check application status
bin/kamal app details

# View logs
bin/kamal app logs -f

# Access Rails console
bin/kamal app exec --interactive "bin/rails console"

# Access database console
bin/kamal app exec --interactive "bin/rails dbconsole"

# SSH into container
bin/kamal app exec --interactive bash

# Restart application
bin/kamal app restart

# Stop application
bin/kamal app stop

# Remove application (keeps volumes)
bin/kamal app remove
```

## Database Management

### Backup Database

```bash
# Create backup
bin/kamal app exec "bin/rails db:backup"

# Or manually backup the volume
docker run --rm -v crystal_plates_db_database:/source -v $(pwd):/backup alpine tar czf /backup/database-backup-$(date +%Y%m%d).tar.gz -C /source .
```

### Restore Database

```bash
# Stop application
bin/kamal app stop

# Restore from backup
docker run --rm -v crystal_plates_db_database:/target -v $(pwd):/backup alpine tar xzf /backup/database-backup-YYYYMMDD.tar.gz -C /target

# Start application
bin/kamal app start
```

### Run Migrations

```bash
# Migrations run automatically on deployment, but you can run manually:
bin/kamal app exec "bin/rails db:migrate"
```

## Troubleshooting

### Check Volume Status

```bash
# List volumes
docker volume ls | grep crystal_plates

# Inspect volume contents
docker run --rm -v crystal_plates_db_database:/data alpine ls -la /data
docker run --rm -v crystal_plates_db_storage:/data alpine ls -la /data
```

### Application Won't Start

```bash
# Check logs
bin/kamal app logs

# Check container status
bin/kamal app details

# Restart application
bin/kamal app restart
```

### SSL Issues

```bash
# Check Traefik (proxy) logs
bin/kamal traefik logs

# Restart proxy
bin/kamal traefik restart
```

### Database Issues

```bash
# Access database directly
bin/kamal app exec --interactive "bin/rails dbconsole"

# Check database files
bin/kamal app exec "ls -la /rails/db/"

# Reset database (WARNING: destroys data)
bin/kamal app exec "bin/rails db:drop db:create db:migrate db:seed"
```

## CI/CD Integration

For automated deployments, add these steps to your CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
- name: Deploy to production
  run: |
    echo "$KAMAL_REGISTRY_PASSWORD" | docker login -u $KAMAL_REGISTRY_USERNAME --password-stdin
    bin/kamal deploy
  env:
    KAMAL_REGISTRY_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
    KAMAL_REGISTRY_PASSWORD: ${{ secrets.DOCKERHUB_TOKEN }}
    RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
```

## Security Notes

- Keep your `config/master.key` and `.kamal/secrets` files secure
- Use environment variables for sensitive data in CI/CD
- Regularly backup your database
- Keep your server and Docker updated
- Consider using a managed database for production

## Support

For issues:
1. Check the logs: `bin/kamal app logs`
2. Verify volume setup: `./scripts/setup_volumes.sh`
3. Check container status: `bin/kamal app details`
4. Review this documentation

---

**Note**: The first deployment may take several minutes as it builds the Docker image and sets up SSL certificates. Subsequent deployments are much faster.
