# Plane Project Management App - Setup Instructions
# Last Updated: 11/6/2025 2:30:00 PM CDT

## Overview
Plane is an open-source project management tool that provides issue tracking, sprints, cycles, and more.

## Prerequisites
1. Docker and Docker Compose installed on tnapp01
2. Environment variables configured in `.env.tnapp01`

## Configuration Steps

### 1. Update Environment Variables
Edit `/home/divix/divtools/docker/sites/s01-7692nh/tnapp01/.env.tnapp01` and change these values:

```bash
# Generate a secure secret key (minimum 50 characters)
export PLANE_SECRET_KEY=your_secure_random_secret_key_here_minimum_50_chars

# Set a strong PostgreSQL password
export PLANE_POSTGRES_PASSWORD=your_strong_db_password_here

# Set MinIO credentials (for file storage)
export PLANE_MINIO_ROOT_USER=admin
export PLANE_MINIO_ROOT_PASSWORD=your_strong_minio_password_here
```

**To generate a secure secret key:**
```bash
openssl rand -base64 48
```

### 2. Create Required Directories
The following directories will be created automatically when you start the containers:
- `/opt/plane/pgdata` - PostgreSQL database
- `/opt/plane/redis` - Redis data
- `/opt/plane/minio` - MinIO object storage
- `/opt/plane/logs` - Application logs

### 3. Start Plane Services
From your divtools docker directory:

```bash
# Start all Plane services
dcup plane

# Or if you have profile-based aliases
dcup --profile plane
```

### 4. Access Plane
Once all containers are running:
- **Plane Web UI**: http://tnapp01:8085 or http://10.1.1.74:8085
- **MinIO Console**: http://tnapp01:9090 (for storage management)

### 5. Initial Setup
1. Open the Plane web interface in your browser
2. Complete the initial setup wizard
3. Create your first workspace and project

## Services Breakdown
The Plane stack includes:
- `plane-db` - PostgreSQL 15 database
- `plane-redis` - Redis for caching and queuing
- `plane-minio` - MinIO for file storage
- `plane-api` - Django backend API
- `plane-web` - Next.js frontend
- `plane-space` - Public workspace viewer
- `plane-worker` - Celery worker for background tasks
- `plane-beat-worker` - Celery beat scheduler
- `plane-proxy` - Nginx reverse proxy

## Management Commands

### View Logs
```bash
docker logs plane-proxy
docker logs plane-api
docker logs plane-worker
docker logs plane-db
```

### Stop Services
```bash
dcdown plane
# Or
docker-compose --profile plane down
```

### Restart Services
```bash
docker restart plane-proxy
docker restart plane-api
```

### Backup Database
```bash
docker exec plane-db pg_dump -U plane plane > plane_backup_$(date +%Y%m%d).sql
```

### Restore Database
```bash
cat plane_backup_YYYYMMDD.sql | docker exec -i plane-db psql -U plane plane
```

## Troubleshooting

### Check Service Health
```bash
docker ps --filter "name=plane-"
```

### Database Connection Issues
```bash
docker exec plane-db pg_isready -U plane
```

### Redis Connection Issues
```bash
docker exec plane-redis redis-cli ping
```

### View API Logs
```bash
docker logs plane-api --tail 100 -f
```

### MinIO Access Issues
1. Ensure the `plane` bucket exists in MinIO
2. Check MinIO credentials match environment variables
3. Access MinIO console at http://tnapp01:9090

## Security Notes
1. **Change all default passwords** in `.env.tnapp01`
2. The Plane proxy is exposed on port 8085 - consider using Traefik for SSL
3. MinIO console is on port 9090 - restrict access or add authentication
4. Database backups should be scheduled regularly

## Integration with Traefik (Optional)
To add SSL and domain-based routing, you can integrate with Traefik:
1. Add labels to the `plane-proxy` service
2. Configure your domain in Traefik
3. Update `CORS_ALLOWED_ORIGINS` in `plane-api` environment

## Updates
To update Plane to the latest version:
```bash
docker-compose --profile plane pull
docker-compose --profile plane up -d
```

## Support
- Plane Documentation: https://docs.plane.so/
- Plane GitHub: https://github.com/makeplane/plane
- Plane Discord: https://discord.com/invite/plane
