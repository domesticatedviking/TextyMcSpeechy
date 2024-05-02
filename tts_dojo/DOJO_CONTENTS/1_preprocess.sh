#!/bin/sh
BIN_DIR=$(cat .BIN_DIR)
echo "BIN_DIR = '$BIN_DIR'"

DOJO_DIR=$(cat .DOJO_DIR)
echo "DOJO_DIR = '$DOJO_DIR'"


cd $PIPER_DIR
echo "Piper DIR = '$PIPER_DIR'"
echo " DOJO DIR = '$DOJO_DIR'"

cd $PIPER_DIR
python3 -m $BIN_DIR/piper_train.preprocess \
  --language en-us \
  --input-dir $DOJO_DIR/target_voice_dataset \
  --output-dir $DOJO_DIR/training_folder \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate 16000
