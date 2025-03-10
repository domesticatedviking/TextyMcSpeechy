#!/bin/sh
# local_container_run.sh  - launches a locally built docker container

# If an argument is provided, use it as GPU_ID
if [ "$#" -ge 1 ]; then
    GPU_ID="$1"
fi

# Set container name and NVIDIA_VISIBLE_DEVICES based on GPU_ID
if [ -n "$GPU_ID" ]; then
    CONTAINER_NAME="textymcspeechy-piper-$GPU_ID"
    NVIDIA_VISIBLE_DEVICES="$GPU_ID"
else
    CONTAINER_NAME="textymcspeechy-piper"
    NVIDIA_VISIBLE_DEVICES="all"
fi

AUTOMATIC_ESPEAK_RULE_SCRIPT="tts_dojo/ESPEAK_RULES/automated_espeak_rules.sh"

# Ensure Docker files exist.
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found! Press <Enter> to exit." >&2
    read
    exit 1
fi

if [ ! -f "Dockerfile" ]; then
    echo "Error: Dockerfile not found! Press <Enter> to exit." >&2
    read
    exit 1
fi

echo "Starting Docker container ${CONTAINER_NAME}"
# Pass PUID and PGID to docker-compose.yml (prepend as environment variables)
export TMS_USER_ID=$(id -u)
export TMS_GROUP_ID=$(id -g)
export CONTAINER_NAME
export NVIDIA_VISIBLE_DEVICES

echo
TMS_USER_ID="${TMS_USER_ID}" TMS_GROUP_ID="${TMS_GROUP_ID}" CONTAINER_NAME="${CONTAINER_NAME}" NVIDIA_VISIBLE_DEVICES="${NVIDIA_VISIBLE_DEVICES}" docker compose up -d
echo
# Apply any custom pronunciation rules configured to run automatically
$AUTOMATIC_ESPEAK_RULE_SCRIPT
