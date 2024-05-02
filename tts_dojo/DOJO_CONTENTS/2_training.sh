#!/bin/sh
PIPER_DIR="/home/erik/code/piper/src/python"
DOJO_DIR="/home/erik/tts_dojo/o2tiny_dojo"

cd $PIPER_DIR
echo "Piper DIR = '$PIPER_DIR'"
echo " DOJO DIR = '$DOJO_DIR'"


python3 -m piper_train \
    --dataset-dir $DOJO_DIR/training_folder/ \
    --accelerator gpu \
    --devices 1 \
    --batch-size 8 \
    --validation-split 0.0 \
    --num-test-examples 0 \
    --max_epochs 30000 \
    --resume_from_checkpoint $DOJO_DIR/pretrained_tts_checkpoints/*.ckpt \
    --checkpoint-epochs 1 \
    --precision 32
