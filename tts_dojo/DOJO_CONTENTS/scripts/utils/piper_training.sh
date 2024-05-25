#!/bin/bash
trap "kill 0" SIGINT
DOJO_DIR=$(cat ../.DOJO_DIR)
PIPER_PATH=$(cat $DOJO_DIR/.PIPER_PATH)
VOICE_NAME=$(cat $DOJO_DIR/.VOICE_NAME)

TTS_VOICES="tts_voices"
EXPORT_START_TIME="/tmp/export_start_time" #save timestamp for beginning of last export
LAST_EXPORT_SECONDS="/tmp/last_voice_export_seconds"

settings_file=$DOJO_DIR/scripts/SETTINGS.txt
if [ -e $settings_file ]; then
    source $settings_file
else
    echo "$0 - settings not found"
    echo "     expected location: $settings_file"
    echo 
    echo "press <enter> to exit"
    exit 1
fi





# Check if the starting checkpoint is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <starting_checkpoint>:path to a checkpoint file"
  exit 1
fi

# Assign the starting checkpoint to a variable
starting_checkpoint=$1

PIPER_PATH=$(cat .PIPER_PATH)
echo "PIPER_PATH = '$PIPER_PATH'"

DOJO_DIR=$(cat .DOJO_DIR)
echo "DOJO_DIR = '$DOJO_DIR'"

cd $PIPER_PATH/src/python
source .venv/bin/activate

python -m piper_train \
    --dataset-dir "$DOJO_DIR/training_folder/" \
    --accelerator gpu \
    --devices 1 \
    --batch-size $PIPER_BATCH_SIZE\
    --validation-split 0.0 \
    --num-test-examples 0 \
    --max_epochs 30000 \
    --resume_from_checkpoint "$starting_checkpoint" \
    --checkpoint-epochs $PIPER_SAVE_CHECKPOINT_EVERY_N_EPOCHS \
    --precision 32

deactivate    
exit 0

