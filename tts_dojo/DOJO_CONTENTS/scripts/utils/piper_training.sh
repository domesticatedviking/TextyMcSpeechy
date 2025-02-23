#!/bin/bash
# scripts/piper_training.sh - Runs training inside docker container.
# Expects one parameter:  a relative path to a starting checkpoint file
echo "Running piper_training.sh"

trap "kill 0" SIGINT
set +e # Exit immediately if any command returns a non-zero exit code

SETTINGS_FILE="SETTINGS.txt"
TRAIN_FROM_SCRATCH_FILE="../target_voice_dataset/.SCRATCH"

# infer name of dojo and voice from directory name
DOJO_NAME=$(basename "$(dirname "$PWD")")  # this script runs from <name>_dojo/scripts so need parent directory   
VOICE_NAME=$(echo "$DOJO_NAME" | sed 's/_dojo$//')

# determine quality
QUALITY=$(cat "../target_voice_dataset/.QUALITY" 2>/dev/null || echo "M")
case $QUALITY in
    "L") QUALITY="low" ;;
    "M") QUALITY="medium" ;;
    "H") QUALITY="high" ;;
esac

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



if [[ -f $TRAIN_FROM_SCRATCH_FILE ]]; then
    TRAIN_FROM_SCRATCH=$(cat $TRAIN_FROM_SCRATCH_FILE)
else
    echo "Error: .SCRATCH file not found: $TRAIN_FROM_SCRATCH_FILE ."
    exit 1 
fi



# Check if the starting checkpoint parameter is provided
if [ -z "$1" ]; then
  echo "No starting checkpoint received."
  
fi

starting_checkpoint=$1
   

# run piper training in docker container (textymcspeechy-piper)
train_from_scratch(){
docker exec textymcspeechy-piper bash -c "cd /app/piper/src/python \
    && python -m piper_train \
    --dataset-dir "/app/tts_dojo/$DOJO_NAME/training_folder/" \
    --accelerator gpu \
    --devices 1 \
    --batch-size $PIPER_BATCH_SIZE\
    --validation-split 0.0 \
    --num-test-examples 0 \
    --max_epochs 30000 \
    --checkpoint-epochs $PIPER_SAVE_CHECKPOINT_EVERY_N_EPOCHS \
    --precision 32 \
    --quality $QUALITY
"
}

train_from_pretrained(){
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
    --precision 32 \
    --quality $QUALITY
"
}

if [ $TRAIN_FROM_SCRATCH == "true" ]; then
    echo
    echo
    echo
    echo "Training model from scratch."
    echo
    echo
    train_from_scratch
else
    echo
    echo
    echo "Training from pretrained checkpoint file:"
    echo "    $starting_checkpoint"
    echo
    echo
    train_from_pretrained
fi


exit 0
