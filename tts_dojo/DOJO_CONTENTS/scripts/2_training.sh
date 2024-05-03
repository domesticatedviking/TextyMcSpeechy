#!/bin/sh

# PIPER_PATH should be inferred automatically from BIN_DIR provided that
# your venv folder is located in /piper/src/python
# Otherwise you can anually add the path below

PIPER_PATH=""   
# Check if the user provided a --piper_path parameter
while [ $# -gt 0 ]; do
    case "$1" in
        --piper_path=*)
            PIPER_PATH="${1#*=}"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

clear

BIN_DIR=$(cat .BIN_DIR)
echo "BIN_DIR= '$BIN_DIR'"

# If PIPER_PATH is still empty, attempt to infer it from BIN_DIR
if [ -z "$PIPER_PATH" ]; then
    # Extract /path/to/piper/
    PIPER_PATH=$(echo "$BIN_DIR" | grep -oP "^.+?/piper/")
fi

echo
echo "/path/to/piper is inferred to be at: $PIPER_PATH" 
echo
echo "    if this is wrong, your venv folder was probably not created in /piper/src/python "
echo "    either: "
echo "            -  reinstall piper with the venv in the right place (don't try to move your venv folder!) "
echo 
echo "            -  edit tts_dojo/DOJO_CONTENTS/2_training.sh and hardcode the path in PIPER_PATH"
echo
echo "            -  or call ./2_training.sh --piper_path path/to/piper"
echo 

DOJO_DIR=$(cat .DOJO_DIR)
echo "DOJO_DIR = '$DOJO_DIR'"


cd $PIPER_PATH
python -m piper_train \
    --dataset-dir $DOJO_DIR/training_folder/ \
    --accelerator gpu \
    --devices 1 \
    --batch-size 8 \
    --validation-split 0.0 \
    --num-test-examples 0 \
    --max_epochs 30000 \
    --resume_from_checkpoint $DOJO_DIR/pretrained_tts_checkpoint/*.ckpt \
    --checkpoint-epochs 1 \
    --precision 32

exit 0
