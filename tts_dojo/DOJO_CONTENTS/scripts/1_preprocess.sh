#!/bin/sh
# NOTE:  This script needs the piper_train module located in piper/src/python
#        TODO: change from a relative directory to determining absolute location
#              of piper/src/python

# Exit immediately if any command returns a non-zero exit code
set -e

# Function to handle errors
error_handler() {
  echo "An error occurred in the script. Exiting with code 1."
  exit 1
}

# Trap errors and call the error_handler function
trap 'error_handler' ERR

BIN_DIR=$(cat .BIN_DIR)
echo "BIN_DIR = '$BIN_DIR'"

DOJO_DIR=$(cat .DOJO_DIR)
echo "DOJO_DIR = '$DOJO_DIR'"

# Change to the appropriate directory
cd ../..  # Need to run from piper/src/python directory/

# Run the Python script
python3 -m piper_train.preprocess \
  --language en-us \
  --input-dir "$DOJO_DIR/target_voice_dataset" \
  --output-dir "$DOJO_DIR/training_folder" \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate 16000

echo "Python script completed successfully."
exit 0
