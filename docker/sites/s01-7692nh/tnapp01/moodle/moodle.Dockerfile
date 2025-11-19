# Custom Moodle Dockerfile with PostgreSQL support
# Last Updated: 11/8/2025 9:45:00 PM CDT

FROM lthub/moodle:master

# Install PostgreSQL development libraries and compile PHP extensions
RUN apt-get update && \
    apt-get install -y \
    libpq-dev \
    postgresql-client \
    wget && \
    docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql && \
    docker-php-ext-install pgsql pdo_pgsql && \
    docker-php-ext-enable pgsql pdo_pgsql && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify extensions are installed during build
RUN echo "=== PostgreSQL Extensions Check (BUILD TIME) ===" && \
    php -m | grep -i pgsql && \
    echo "PostgreSQL extensions successfully installed" && \
    echo "=== PHP CLI Config ===" && \
    php --ini && \
    echo "=== Extension files ===" && \
    ls -la /usr/local/lib/php/extensions/*/pgsql* /usr/local/lib/php/extensions/*/pdo_pgsql* || echo "Extensions not in expected location" && \
    echo "=== PHP config dir ===" && \
    ls -la /usr/local/etc/php/conf.d/ || echo "conf.d not found"

# Download and extract Moodle (latest stable version)
# Check https://download.moodle.org/releases/latest/ for latest version
# Updated URL format - using direct download link for Moodle 4.5
ARG MOODLE_VERSION=4.5.1
RUN cd /tmp && \
    wget https://download.moodle.org/download.php/direct/stable405/moodle-${MOODLE_VERSION}.tgz && \
    tar -xzf moodle-${MOODLE_VERSION}.tgz && \
    rm -rf /var/www/html/* && \
    mv moodle/* /var/www/html/ && \
    rm -rf /tmp/moodle* && \
    chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html

# Create a backup of Moodle files for when volume is mounted empty
RUN cp -a /var/www/html /tmp/moodle_backup

# Final verification that PostgreSQL extensions are available
RUN php -m | grep -E "pgsql|pdo_pgsql" && \
    echo "PostgreSQL PHP extensions confirmed installed"

# Set default Moodle data directory
ENV MOODLE_DATA_ROOT=/var/moodledata

# Ensure moodledata directory exists and has correct permissions
RUN mkdir -p /var/moodledata && \
    chown -R www-data:www-data /var/moodledata && \
    chmod -R 0777 /var/moodledata

# Copy custom initialization script that creates config.php
COPY init-moodle.sh /usr/local/bin/init-moodle.sh
RUN chmod +x /usr/local/bin/init-moodle.sh

# Use our custom entrypoint that creates config.php before calling original entrypoint
ENTRYPOINT ["/usr/local/bin/init-moodle.sh"]
CMD ["/usr/sbin/apachectl", "-e", "info", "-D", "FOREGROUND"]
