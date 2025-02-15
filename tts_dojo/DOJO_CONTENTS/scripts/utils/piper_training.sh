#!/bin/bash
# scripts/piper_training.sh - Runs training inside docker container.
# Expects one parameter:  a relative path to a starting checkpoint file
echo "Running piper_training.sh"

trap "kill 0" SIGINT
set +e # Exit immediately if any command returns a non-zero exit code

SETTINGS_FILE="SETTINGS.txt"
# infer name of dojo and voice from directory name
DOJO_NAME=$(basename "$(dirname "$PWD")")  # this script runs from <name>_dojo/scripts so need parent directory   
VOICE_NAME=$(echo "$DOJO_NAME" | sed 's/_dojo$//')

# sanity check for current directory
if [[ ! "$DOJO_NAME" =~ _dojo$ ]]; then
    echo "Error: DOJO_NAME did not end with '_dojo'. Are you running from <voice>_dojo/scripts directory?  Exiting." >&2
    exit 1
fi

# load training settings from SETTINGS_FILE
if [ -e $SETTINGS_FILE ]; then
    source $SETTINGS_FILE
else
    echo "$0 - settings not found"
    echo "     expected location: $SETTINGS_FILE"
    echo 
    echo "press <enter> to exit"
    exit 1
fi

# Check if the starting checkpoint parameter is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <starting_checkpoint>:path to a checkpoint file"
  exit 1
fi
starting_checkpoint=$1
echo
echo
echo "starting_checkpoint path = $starting_checkpoint"
echo
echo

# run piper training in docker container (textymcspeechy-piper)
docker exec textymcspeechy-piper bash -c "cd /app/piper/src/python \
    && python -m piper_train \
    --dataset-dir "/app/tts_dojo/$DOJO_NAME/training_folder/" \
    --accelerator gpu \
    --devices 1 \
    --batch-size $PIPER_BATCH_SIZE\
    --validation-split 0.0 \
    --num-test-examples 0 \
    --max_epochs 30000 \
    --resume_from_checkpoint "$starting_checkpoint" \
    --checkpoint-epochs $PIPER_SAVE_CHECKPOINT_EVERY_N_EPOCHS \
    --precision 32
"

exit 0
