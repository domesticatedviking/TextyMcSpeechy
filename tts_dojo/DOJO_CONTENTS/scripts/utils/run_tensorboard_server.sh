#!/bin/sh
# run_tensorboard_server.sh
# Displays instructions for viewing tensorboard server output and launches server on textymcspeechy-piper container
# it is assumed that textymcspeechy-piper is already running
DOJO_NAME=$1
LIGHTNING_LOGS_PATH=/app/tts_dojo/${DOJO_NAME}/training_folder/lightning_logs
clear
echo "   View training progress with Tensorboard"
echo "   open http://localhost:6006 in your web browser"    

docker exec -it textymcspeechy-piper tensorboard --logdir "${LIGHTNING_LOGS_PATH}" --bind_all >/dev/null 2>&1
read # holds window waiting for input to suppress command prompt
