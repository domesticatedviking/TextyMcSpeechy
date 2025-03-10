#!/bin/bash
# run_tensorboard_server.sh
# Displays instructions for viewing tensorboard server output and launches the server on the textymcspeechy-piper container.
# It is assumed that textymcspeechy-piper is already running.

DOJO_NAME=$1

# Determine the location of the .gpu file. This file is located in the parent folder (scripts/) of this script's folder (scripts/utils/)
GPU_CONF_FILE="$(dirname "$0")/../.gpu"
if [ -f "$GPU_CONF_FILE" ]; then
    # Source silently (if the .gpu file exists, it will set GPU_ID)
    source "$GPU_CONF_FILE"
fi

# Set container name based on whether GPU_ID is defined
if [ -n "$GPU_ID" ]; then
    CONTAINER_NAME="textymcspeechy-piper-$GPU_ID"
else
    CONTAINER_NAME="textymcspeechy-piper"
fi

LIGHTNING_LOGS_PATH="/app/tts_dojo/${DOJO_NAME}/training_folder/lightning_logs"

clear
echo "   View training progress with Tensorboard"
echo "   Open http://localhost:6006 in your web browser"

docker exec -it "$CONTAINER_NAME" tensorboard --logdir "${LIGHTNING_LOGS_PATH}" --bind_all >/dev/null 2>&1
read  # hold the window open waiting for input
