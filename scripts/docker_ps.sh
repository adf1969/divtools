#!/bin/bash

# Define the printf format string
#format="%-14s %-16s %-18s %-14s %-16s %-14s\n"
format="%-14.14s %-16.16s %-18.18s %-14.14s %-16.16s %-14.14s\n"

# Print header
printf "$format" "ContainerID" "Name" "Image" "Status" "Ports" "IP Address"

# Fetch and process container information
docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | while IFS=$'\t' read -r id name image status ports; do
    ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$id")
    # Replace 0.0.0.0 with 0 and limit ports to 14 characters
    ports=$(echo "$ports" | sed 's/0.0.0.0/0/g' | cut -c1-14)
    printf "$format" "$id" "$name" "$image" "$status" "$ports" "$ip"
done
