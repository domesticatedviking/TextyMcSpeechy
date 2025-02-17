#!/bin/sh
# locak_container_run.sh  - launches a locally built docker container  

# ensure docker files exist.
if [[ ! -f "docker-compose.yml" ]]; then
    echo "Error: docker-compose.yml not found! Press <Enter> to exit." >&2
    read
    exit 1
fi

if [[ ! -f "Dockerfile" ]]; then
    echo "Error: Dockerfile not found! Press <Enter> to exit." >&2
    read
    exit 1
fi

echo "Starting Docker container textymcspeechy-piper"
# pass PUID and PGID to docker-compose.yml (prepend as environment vars) 
# Ensures current user will have rights to files created by docker container in mounted folder
export TMS_USER_ID=$(id -u)
export TMS_GROUP_ID=$(id -g)
echo
TMS_USER_ID="${TMS_USER_ID}" TMS_GROUP_ID="${TMS_GROUP_ID}" docker compose up -d
echo



