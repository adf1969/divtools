# Dockerfile for dthostmon
# Last Updated: 11/14/2025 12:00:00 PM CDT

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies including curl for OpenCode installation
RUN apt-get update && apt-get install -y \
    openssh-client \
    cron \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install OpenCode CLI
RUN curl -L https://get.opencode.ai/linux | bash

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ /app/src/
COPY config/ /app/config/

# Create necessary directories
RUN mkdir -p /opt/dthostmon/config \
    /opt/dthostmon/logs \
    /opt/dthostmon/.ssh \
    /root/.local/share/opencode \
    && chmod 700 /opt/dthostmon/.ssh

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose API port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import requests; requests.get('http://localhost:8080/health')" || exit 1

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command (can be overridden)
CMD ["api"]
