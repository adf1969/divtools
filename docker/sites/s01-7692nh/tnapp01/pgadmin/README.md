# pgAdmin 4 - PostgreSQL Administration Tool

## Overview
pgAdmin is a comprehensive web-based administration and development platform for PostgreSQL databases. It provides an intuitive graphical interface for managing databases, executing queries, and monitoring database performance.

## Features
- Visual database management and query building
- SQL query editor with syntax highlighting
- Database backup and restore capabilities
- User and permission management
- Performance monitoring and query analysis
- Server connection management
- Import/Export data tools

## Directory Structure
```
pgadmin/
├── config/              # pgAdmin configuration and server definitions
│                        # Mapped to: /var/lib/pgadmin in container
├── dci-pgadmin.yml     # Docker Compose configuration
└── README.md           # This file
```

## Persistent Data Locations
- **Config/Sessions**: `$DOCKERDIR/sites/s01-7692nh/tnapp01/pgadmin/config`
- **Storage/Data**: `$DOCKERDATADIR/pgadmin` (typically `/opt/pgadmin`)

## Configuration

### Environment Variables
Set in `.env.tnapp01` (optional):
```bash
export PGADMIN_PORT=8080  # Web interface port (default: 8080)
```

### Secrets Required
Located in `$DOCKERDIR/secrets/`:
- `pgadmin-default-email` - Login email address
- `pgadmin-default-password` - Login password

## Usage

### Starting pgAdmin
```bash
# Start using the dbs profile
dcup --profile dbs

# Or start directly by name
dcup pgadmin
```

### Stopping pgAdmin
```bash
# Stop using the dbs profile
dcdown --profile dbs

# Or stop directly by name
dcdown pgadmin
```

### Accessing pgAdmin
1. Open web browser to: `http://tnapp01:8080` (or `http://10.1.1.74:8080`)
2. Login with credentials from secret files
3. Add database server connections as needed

## Connecting to PostgreSQL Databases

### Adding a Server Connection
1. In pgAdmin, right-click **Servers** → **Register** → **Server**
2. **General Tab**:
   - Name: `Moodle DB` (or any descriptive name)
3. **Connection Tab**:
   - Host: `moodle-db` (container name) or `10.1.1.74`
   - Port: `5434` (for Moodle) or `5432` (for main postgres)
   - Maintenance database: `postgres` (or specific DB name)
   - Username: Database username (e.g., `moodle`)
   - Password: From `.env.tnapp01` (e.g., `$MOODLE_DB_PASSWORD`)
   - Save password: ✓ (optional)

### Common Database Connections on tnapp01

#### Moodle Database
- **Host**: `moodle-db` or `10.1.1.74`
- **Port**: `5434`
- **Database**: `moodle`
- **User**: `moodle`
- **Password**: `${MOODLE_DB_PASSWORD}` from `.env.tnapp01`

#### n8n Database
- **Host**: `n8n-postgres` or `10.1.1.74`
- **Port**: `5432`
- **Database**: `n8n`
- **User**: `n8n`
- **Password**: From `n8n-postgres-db-password` secret

#### Plane Database
- **Host**: `plane-postgres` or `10.1.1.74`
- **Port**: `5433` (if configured)
- **Database**: `plane`
- **User**: `plane`
- **Password**: `${PLANE_POSTGRES_PASSWORD}` from `.env.tnapp01`

### Network Connectivity
pgAdmin runs on the default bridge network, allowing it to connect to:
- Other containers by container name (e.g., `moodle-db`)
- Host PostgreSQL instances via host IP (`10.1.1.74`)
- External PostgreSQL servers (if network permits)

## Configuration Files

### Server Configuration
pgAdmin stores server definitions in: `config/servers.json`

To pre-configure servers, create `config/servers.json`:
```json
{
  "Servers": {
    "1": {
      "Name": "Moodle Database",
      "Group": "Servers",
      "Host": "moodle-db",
      "Port": 5432,
      "MaintenanceDB": "moodle",
      "Username": "moodle",
      "SSLMode": "prefer",
      "Comment": "Moodle PostgreSQL Database"
    }
  }
}
```

### pgAdmin Configuration
Settings are stored in `config/` and persist across container restarts.

## Troubleshooting

### Cannot Login
- Verify secrets exist: `ls -la $DOCKERDIR/secrets/pgadmin-*`
- Check secret file contents are not empty
- Restart container: `dcrestart pgadmin`

### Cannot Connect to Database
- Verify target database container is running: `docker ps | grep postgres`
- Check database port mapping: `docker port <container-name>`
- Verify credentials match those in `.env.tnapp01`
- Test connection from host: `psql -h localhost -p 5434 -U moodle -d moodle`

### Port 8080 Already in Use
- Change port in `.env.tnapp01`: `export PGADMIN_PORT=8081`
- Restart pgAdmin: `dcrestart pgadmin`

### Permission Errors
- Check volume permissions: `ls -la /opt/pgadmin`
- Fix permissions if needed: 
  ```bash
  sudo chown -R 5050:5050 /opt/pgadmin
  sudo chmod -R 755 /opt/pgadmin
  ```
  (pgAdmin runs as UID 5050 by default)

### View Logs
```bash
docker logs pgadmin
docker logs -f pgadmin  # Follow logs
```

## Maintenance

### Backup pgAdmin Configuration
```bash
# Backup server definitions and settings
tar -czf pgadmin-config-backup-$(date +%Y%m%d).tar.gz \
  /opt/divtools/docker/sites/s01-7692nh/tnapp01/pgadmin/config
```

### Update pgAdmin
```bash
# Pull latest image and recreate container
dcpull pgadmin
dcup --force-recreate pgadmin
```

### Reset pgAdmin
```bash
# Stop container
dcdown pgadmin

# Clear configuration (WARNING: loses all settings and saved servers)
rm -rf /opt/divtools/docker/sites/s01-7692nh/tnapp01/pgadmin/config/*
rm -rf /opt/pgadmin/*

# Restart
dcup pgadmin
```

## Security Notes
- pgAdmin is configured in **desktop mode** (single user)
- No master password required for saved database passwords
- Session does not expire (timeout = 0)
- Credentials stored in Docker secrets
- Only accessible on local network (no external exposure by default)

## Integration with Other Services

### With Traefik (if configured)
To expose pgAdmin through Traefik, add labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.pgadmin.rule=Host(`pgadmin.l1.divix.biz`)"
  - "traefik.http.services.pgadmin.loadbalancer.server.port=80"
```

### With Monitoring
pgAdmin health checks are configured and can be monitored via:
- Docker health status: `docker ps --format "{{.Names}}: {{.Status}}"`
- Direct ping endpoint: `curl http://tnapp01:8080/misc/ping`

## Profiles
- **dbs**: Database services profile (includes pgAdmin and related DB containers)

## Resources
- [pgAdmin Official Documentation](https://www.pgadmin.org/docs/)
- [pgAdmin Docker Hub](https://hub.docker.com/r/dpage/pgadmin4)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## Last Updated
11/8/2025 12:15:00 PM CST
