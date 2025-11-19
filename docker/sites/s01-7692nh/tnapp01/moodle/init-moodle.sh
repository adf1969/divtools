#!/bin/bash
# Initialize Moodle configuration
# Last Updated: 11/8/2025 10:35:00 PM CDT

set -e

# Check if /var/www/html is empty (volume mounted but empty)
# If so, we need to copy Moodle files from the image
if [ ! -f "/var/www/html/index.php" ]; then
    echo "Moodle files not found in /var/www/html, checking for backup..."
    
    # Check if we have a backup of the Moodle installation
    if [ -d "/tmp/moodle_backup" ]; then
        echo "Copying Moodle files from backup to /var/www/html..."
        cp -a /tmp/moodle_backup/. /var/www/html/
        chown -R www-data:www-data /var/www/html
    else
        echo "ERROR: Moodle files not found! The /var/www/html directory is empty."
        echo "This should not happen. Check the Dockerfile."
    fi
fi

CONFIG_FILE="/var/www/html/config.php"

# Only create config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating Moodle config.php with database settings..."
    
    cat > "$CONFIG_FILE" << 'EOF'
<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = getenv('MOODLE_DB_TYPE') ?: 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('MOODLE_DB_HOST') ?: 'localhost';
$CFG->dbname    = getenv('MOODLE_DB_NAME') ?: 'moodle';
$CFG->dbuser    = getenv('MOODLE_DB_USER') ?: 'moodle';
$CFG->dbpass    = getenv('MOODLE_DB_PASSWORD') ?: '';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => getenv('MOODLE_DB_PORT') ?: '5432',
  'dbsocket' => '',
);

// Set wwwroot to the direct IP:PORT access (change this after installation if needed)
$CFG->wwwroot   = 'http://10.1.1.74:9090';
$CFG->dataroot  = '/var/moodledata';
$CFG->admin     = 'admin';

$CFG->directorypermissions = 0777;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF

    chown www-data:www-data "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
    echo "config.php created successfully."
else
    echo "config.php already exists, skipping creation."
fi

# Continue with original entrypoint
exec /docker-entrypoint.sh "$@"
