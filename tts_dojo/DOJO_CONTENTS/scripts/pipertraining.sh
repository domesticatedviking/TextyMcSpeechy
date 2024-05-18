#!/bin/bash
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
    --batch-size 2 \
    --validation-split 0.0 \
    --num-test-examples 0 \
    --max_epochs 30000 \
    --resume_from_checkpoint "$DOJO_DIR/pretrained_tts_checkpoint/"*.ckpt \
    --checkpoint-epochs 1 \
    --precision 32
deactivate    
exit 0

