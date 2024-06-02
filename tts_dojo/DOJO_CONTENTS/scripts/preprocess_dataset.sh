#!/bin/bash


# Exit immediately if any command returns a non-zero exit code
set -e

current_dir=$(pwd)



# Function to handle errors
error_handler() {
  echo "An error occurred in the script. Exiting."
  exit 1
}
export -f error_handler
# Trap errors and call the error_handler function
trap 'error_handler' ERR SIGINT SIGTERM

BIN_DIR=$(cat .BIN_DIR)
#echo "BIN_DIR = '$BIN_DIR'"

PIPER_PATH=$(cat .PIPER_PATH)
#echo "PIPER_PATH = '$PIPER_PATH'"

DOJO_DIR=$(cat .DOJO_DIR)
#echo "DOJO_DIR = '$DOJO_DIR'"
cd $DOJO_DIR/scripts


if [ -e "SETTINGS.txt" ]; then 
    source "SETTINGS.txt"
else
    echo "could not find scripts/SETTINGS.txt.   exiting."
    exit 1
fi

SAMPLING_RATE=$(cat .SAMPLING_RATE)      #inferred by dataset sanitizer
echo -e "       Auto-configured sampling rate: $SAMPLING_RATE"

MAX_WORKERS=$(cat .MAX_WORKERS)          #calculated by dataset sanitizer.
echo -e "    Calculated value for max-workers: $MAX_WORKERS"
echo
echo
echo "Running piper_train.preprocess"
echo
echo
# Change to the appropriate directory
cd $PIPER_PATH/src/python  # Need to run from piper/src/python directory/


LANGUAGE=$PIPER_TTS_LANGUAGE #eg, en-us

# Run the Python script
python3 -m piper_train.preprocess \
  --language $LANGUAGE \
  --input-dir "$DOJO_DIR/target_voice_dataset" \
  --output-dir "$DOJO_DIR/training_folder" \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate ${SAMPLING_RATE} \
  --max-workers ${MAX_WORKERS}
result=$?
if [ $result -eq 0 ];then 
    echo
    echo
    echo
    echo "    Successfully preprocessed dataset."
    echo 
    echo "    Press <ENTER> to continue"
    read
    echo
else
    echo  "piper_train.preprocess failed.  Press <enter> to exit."
    read
    exit 1
fi
cd $DOJO_DIR/scripts
exit 0
