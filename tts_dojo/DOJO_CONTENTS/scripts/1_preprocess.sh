#!/bin/sh
# NOTE:  This script needs the piper_train module located in piper/src/python
#        TODO: change from a relative directory to determining absolute location
#              of piper/src/python

BIN_DIR=$(cat .BIN_DIR)
echo "BIN_DIR = '$BIN_DIR'"

DOJO_DIR=$(cat .DOJO_DIR)
echo "DOJO_DIR = '$DOJO_DIR'"

cd ../..  #need to run from piper/src/python directory/
python3 -m piper_train.preprocess \
  --language en-us \
  --input-dir $DOJO_DIR/target_voice_dataset \
  --output-dir $DOJO_DIR/training_folder \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate 16000
