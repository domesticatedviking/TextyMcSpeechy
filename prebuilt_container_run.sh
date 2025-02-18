#!/bin/bash
# prebuilt_container_run.sh  - Launches a prebuilt image of textymcspeechy-piper

# Path to script that sets which custom pronunciation rules will be applied when the container is brought up
AUTOMATIC_ESPEAK_RULE_SCRIPT="tts_dojo/ESPEAK_RULES/automated_espeak_rules.sh"
fail=0  
# Check that docker is installed
if command -v docker &> /dev/null; then
    :       
else
    echo "WARNING -- Required package Docker is not installed."
    echo "install instructions can be found here:"
    echo "https://docs.docker.com/engine/install/"
    echo
    echo
    fail=1
fi

# Check that NVIDIA container toolkit is installed
if dpkg -l | grep -q nvidia-container-toolkit; then
    :
else
    echo "WARNING! -- Required package NVIDIA Container Toolkit is not installed."
    echo "install instructions can be found here:"
    echo "https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
    echo
    echo
    fail=1
fi

if [[ $fail -eq 1 ]]; then
    echo "Unable to proceed without required tools."
    echo
    echo "Press <Enter> to exit"
    echo
    exit 1
 fi


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

# Check if the Docker image is present
if ! docker image inspect $IMAGE_NAME > /dev/null 2>&1; then
    echo "Docker image $IMAGE_NAME not found locally. Pulling image..."
    docker pull $IMAGE_NAME
    if [ $? -ne 0 ]; then
        echo "Failed to pull Docker image $IMAGE_NAME."
        exit 1
    fi
fi

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
    # Apply any custom pronunciation rules configured to run automatically
    $AUTOMATIC_ESPEAK_RULE_SCRIPT
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "Failed to start the container."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
