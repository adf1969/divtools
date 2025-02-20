#!/bin/sh

# DB Backup
docker exec -i netbox-postgres-1 /usr/local/bin/pg_dump -U netbox -h 127.0.0.1 -d netbox | gzip > /opt/netbox/postgres-bk/netbox_$(date +%Y-%m-%d).psql.gz

# Delete backups older the 14 days but not first of the month
find /opt/netbox/postgres-bk/ ! -name '*01.psql.gz' ! -name 'backup.sh' -mmin +$((14*60*24)) -exec rm -f {} \;