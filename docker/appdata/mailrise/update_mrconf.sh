#!/bin/bash

# Define the paths
MAILRISE_CONF_TEMPLATE="/opt/divtools/docker/appdata/mailrise/mailrise.conf"
ENV_FILE="/opt/divtools/docker/.env"
MAILRISE_CONF_OUTPUT="/opt/mailrise/mailrise.conf"

# Load environment variables from the .env file
export $(grep -v '^#' "$ENV_FILE" | xargs)

# Use envsubst to replace variables in the template and save the result to the output file
envsubst < "$MAILRISE_CONF_TEMPLATE"> "$MAILRISE_CONF_OUTPUT"

    # Check if the substitution was successful
    if [ $? -eq 0 ]; then
    echo "mailrise.conf has been successfully updated and saved to $MAILRISE_CONF_OUTPUT."
    else
    echo "Error: Failed to process the mailrise.conf template."
    exit 1
    fi