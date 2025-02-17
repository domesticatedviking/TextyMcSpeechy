#!/bin/bash
# prebuilt_container_run.sh  - Launches a prebuilt image of textymcspeechy-piper

# Set default values if not provided
TMS_USER_ID=${TMS_USER_ID:-1000}
TMS_GROUP_ID=${TMS_GROUP_ID:-1000}
TMS_VOLUME_PATH="./tts_dojo"
CONTAINER_NAME="textymcspeechy-piper"
IMAGE_NAME="domesticatedviking/textymcspeechy-piper"

# Print info
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Starting Docker container: $CONTAINER_NAME"
echo "              Using image: $IMAGE_NAME"
echo "          Running as user: UID=$TMS_USER_ID, GID=$TMS_GROUP_ID"
echo "          Mounting volume: $TMS_VOLUME_PATH:/app/tts_dojo"
echo "                    Ports: Exposing 6006 for TensorBoard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


# Run the docker container with CUDA support
docker run --rm -d \
  --name $CONTAINER_NAME \
  --hostname $CONTAINER_NAME \
  --volume $TMS_VOLUME_PATH:/app/tts_dojo \
  --runtime nvidia \
  --env PUID=$TMS_USER_ID \
  --env PGID=$TMS_GROUP_ID \
  --env NVIDIA_VISIBLE_DEVICES=all \
  --env NVIDIA_DRIVER_CAPABILITIES=compute,utility \
  --user "$TMS_USER_ID:$TMS_GROUP_ID" \
  --tty \
  -p 6006:6006 \
  $IMAGE_NAME

# Check if the container is running
if [ $? -eq 0 ]; then
    echo "Container $CONTAINER_NAME started successfully." 
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "Failed to start the container."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

