#!/bin/sh
# NOTE:  This script needs the piper_train module located in piper/src/python
#        TODO: change from a relative directory to determining absolute location
#              of piper/src/python

# Exit immediately if any command returns a non-zero exit code
set -e
current_dir=$(pwd)
#echo "current_dir = $current_dir"

# Function to handle errors
error_handler() {
  echo "An error occurred in the script. Exiting with code 1."
  exit 1
}

# Trap errors and call the error_handler function
trap 'error_handler' ERR

BIN_DIR=$(cat .BIN_DIR)
#echo "BIN_DIR = '$BIN_DIR'"

PIPER_PATH=$(cat .PIPER_PATH)
#echo "PIPER_PATH = '$PIPER_PATH'"

DOJO_DIR=$(cat .DOJO_DIR)
#echo "DOJO_DIR = '$DOJO_DIR'"
cd $DOJO_DIR/scripts

SAMPLING_RATE=$(cat .SAMPLING_RATE)
echo "SAMPLING_RATE = '$SAMPLING_RATE'"

MAX_WORKERS=$(cat .MAX_WORKERS)
echo "MAX_WORKERS = '$MAX_WORKERS'"

# Change to the appropriate directory
cd $PIPER_PATH/src/python  # Need to run from piper/src/python directory/


LANGUAGE="en-us" #language configuration

# Run the Python script
python3 -m piper_train.preprocess \
  --language $LANGUAGE \
  --input-dir "$DOJO_DIR/target_voice_dataset" \
  --output-dir "$DOJO_DIR/training_folder" \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate ${SAMPLING_RATE} \
  --max-workers ${MAX_WORKERS}
echo
echo ".scripts/1_preprocess.sh:  Preprocessing of dataset completed successfully."
cd $DOJO_DIR/scripts
exit 0
