#!/bin/bash

# Output the header
echo -e "ContainerID\tName\tImage\tStatus\tPorts\tIP Address"

# Loop over each running container
for container in $(docker ps -q); do
    # Get container details
    container_id=$(docker inspect -f '{{.ID}}' $container)
    name=$(docker inspect -f '{{.Name}}' $container | sed 's/^\///')
    image=$(docker inspect -f '{{.Config.Image}}' $container)
    status=$(docker inspect -f '{{.State.Status}}' $container)
    ports=$(docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}}:{{(index $conf 0).HostPort}} {{end}}' $container)
    ip_address=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container)
    
    # Output the container details
    echo -e "$container_id\t$name\t$image\t$status\t$ports\t$ip_address"
done

