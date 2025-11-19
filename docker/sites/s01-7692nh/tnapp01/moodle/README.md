# Moodle Docker Setup - Configuration Guide
# Last Updated: 11/7/2025 2:30:00 PM CDT

## Overview
This Moodle installation uses Docker Compose with PostgreSQL database, following your existing patterns for tnapp01.

## File Location
`/home/divix/divtools/docker/sites/s01-7692nh/tnapp01/moodle/dci-moodle.yml`

## Required Environment Variables
Add these variables to your `.env.tnapp01` file:

```bash
# Moodle Configuration
MOODLE_DB_PASSWORD=<generate-with-openssl-rand-base64-48>
MOODLE_ADMIN_PASSWORD=<your-secure-admin-password>
MOODLE_ADMIN_EMAIL=admin@yourdomain.com
MOODLE_SITE_NAME="My Moodle LMS"
MOODLE_SKIP_INSTALL=no
MOODLE_LANG=en
```

Note: `MOODLE_DB_ROOT_PASSWORD` is not needed for PostgreSQL.

## Starting Moodle
Use the dcrun_f() function from your .bash_profile:

```bash
dcup moodle
# or
dcup --profile moodle
```

## Services Included
1. **moodle-db** - PostgreSQL 16 database
2. **moodle-redis** - Redis cache for performance
3. **moodle** - Main Moodle application (Apache/PHP)
4. **moodle-cron** - Automated cron jobs (runs every 60 seconds)

## Exposed Ports
- **8090:80** - HTTP (web interface)
- **8443:443** - HTTPS (if configured)

## Data Volumes
All data stored in `$DOCKERDATADIR/moodle/`:
- `pgdata/` - PostgreSQL database files
- `redis/` - Redis cache
- `moodledata/` - Moodle data directory (uploads, cache, etc.)
- `html/` - Moodle application files

## First-Time Setup Steps

### 1. Generate Secure Passwords
```bash
# Generate passwords
openssl rand -base64 48
```

### 2. Add Environment Variables
Edit your `.env.tnapp01` file and add the Moodle variables listed above.

### 3. Create Required Directories (if not auto-created)
```bash
sudo mkdir -p /opt/moodle/{pgdata,redis,moodledata,html}
sudo chown -R 33:33 /opt/moodle/moodledata
sudo chown -R 33:33 /opt/moodle/html
sudo chmod -R 755 /opt/moodle/moodledata
```

### 4. Start the Services
```bash
cd /opt/divtools/docker/sites/s01-7692nh/tnapp01/moodle
dcup --profile moodle
```

### 5. Monitor Startup
```bash
docker logs -f moodle
```

### 6. Access Moodle
Open browser to: `http://tnapp01:8090`

If first-time setup, follow the web installer or the app will auto-install based on environment variables.

## Post-Installation Configuration

### Traefik Integration (Optional)
To expose Moodle via Traefik, add labels to the moodle service:

```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.moodle.rule=Host(`moodle.${DOMAINNAME_2}`)"
      - "traefik.http.routers.moodle.entrypoints=websecure"
      - "traefik.http.routers.moodle.tls.certresolver=cloudflare"
      - "traefik.http.services.moodle.loadbalancer.server.port=80"
```

And connect to the t3_proxy network:
```yaml
    networks:
      - moodle-network
      - t3_proxy
```

Then add to the bottom networks section:
```yaml
  t3_proxy:
    name: t3_proxy
    external: true
```

### Backup Strategy
Add to your existing PBS backup scripts:
```bash
# Backup Moodle database
docker exec moodle-db pg_dump -U moodle moodle > moodle-backup.sql

# Or with password from env
docker exec moodle-db pg_dump -U moodle -d moodle > moodle-backup-$(date +%Y%m%d).sql

# Backup volumes
tar -czf moodle-data-backup.tar.gz /opt/moodle/moodledata
```

## Common Issues & Solutions

### Issue: Permission Denied on moodledata
**Solution:**
```bash
sudo chown -R 33:33 /opt/moodle/moodledata
sudo chmod -R 755 /opt/moodle/moodledata
```

### Issue: Database Connection Failed
**Check:**
1. Ensure moodle-db is healthy: `docker ps | grep moodle-db`
2. Check database logs: `docker logs moodle-db`
3. Verify password in .env file matches

### Issue: Upload File Size Limit
**Solution:** Already configured in compose file:
- `PHP_UPLOAD_MAX_FILESIZE=256M`
- `PHP_POST_MAX_SIZE=256M`

Adjust as needed in the environment section.

### Issue: Slow Performance
**Solutions:**
1. Redis is already configured for caching
2. Increase PostgreSQL buffers (already optimized in compose file):
   - `shared_buffers=256MB`
   - `effective_cache_size=1GB`
3. Ensure LXC has adequate RAM (8GB+ recommended)
4. Consider adjusting PostgreSQL settings in the command section

### Issue: Cron Not Running
**Check:**
```bash
docker logs moodle-cron
```

Should show cron execution every minute.

## Maintenance Commands

### Stop Moodle
```bash
dcdown --profile moodle
```

### Restart Moodle
```bash
dcrestart --profile moodle
```

### Update Moodle
```bash
dcpull --profile moodle
dcdown --profile moodle
dcup --profile moodle
```

### Access Moodle CLI
```bash
docker exec -it moodle bash
cd /var/www/html
php admin/cli/maintenance.php --enable
```

### Database Backup
```bash
docker exec moodle-db pg_dump -U moodle -d moodle > moodle-$(date +%Y%m%d).sql
```

## PostgreSQL Management with pgAdmin
Since you're using the shared PostgreSQL instance with pgAdmin, you can connect Moodle to it:

### Option 1: Use Standalone Moodle Database (Current Setup)
- Moodle has its own dedicated PostgreSQL container
- Isolated and independent
- Current configuration

### Option 2: Use Shared PostgreSQL Instance
If you want to use your existing `postgres` container from `dci-postgres.yml`:

1. Remove the `moodle-db` service from this file
2. Create the moodle database in your shared PostgreSQL:
   ```bash
   docker exec -it postgres psql -U postgres -c "CREATE DATABASE moodle;"
   docker exec -it postgres psql -U postgres -c "CREATE USER moodle WITH PASSWORD 'your-password';"
   docker exec -it postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE moodle TO moodle;"
   ```
3. Update the `MOODLE_DATABASE_HOST` to point to your shared postgres container
4. Ensure both containers are on the same network or use container name resolution

### Accessing Moodle DB via pgAdmin
1. Start pgAdmin: `dcup --profile dbs`
2. Open pgAdmin at `http://tnapp01:8080`
3. Add new server:
   - **Name**: Moodle Database
   - **Host**: moodle-db (or postgres if using shared)
   - **Port**: 5432
   - **Database**: moodle
   - **Username**: moodle
   - **Password**: `${MOODLE_DB_PASSWORD}`

## Monitoring Integration
Add to your existing Prometheus/Telegraf monitoring:
- Moodle container metrics via cAdvisor (already configured)
- PostgreSQL metrics via postgres_exporter (optional)
- Redis metrics via redis_exporter (optional)

## Security Considerations
1. ✅ Database password stored in .env file
2. ✅ Redis not exposed externally
3. ✅ Database not exposed externally
4. ⚠️  HTTP port 8090 exposed - use Traefik for HTTPS
5. ✅ MOODLE_SSLPROXY=true for reverse proxy support

## Next Steps
1. Generate secure passwords
2. Add environment variables to `.env.tnapp01`
3. Start services with `dcup --profile moodle`
4. Configure Traefik integration (optional)
5. Set up backups
6. Configure monitoring alerts
