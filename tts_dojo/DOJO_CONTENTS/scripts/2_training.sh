#!/bin/sh

# Function to check and possibly delete the 'lightning_logs' folder
check_lightning_logs() {
    if [ -d "$1" ]; then
        echo
        echo "Previous training data was found in training_folder/lightning_logs."
	echo "This could be the result of a previous failed training attempt"
	echo
        echo "Options: [D]elete old data and start training, [S]kip the training, [Q]uit"
	echo

        while true; do
            read -p "What would you like to do? (D/S/Q): " option
            case "$option" in
                [Dd]* )
                    rm -rf "$1"
                    echo "'lightning_logs' folder deleted."
                    break
                    ;;
                [Ss]* )
                    echo "Skipping step and continuing."
                    exit 0
                    ;;
                [Qq]* )
                    echo "Exiting script."
                    exit 1
                    ;;
                * )
                    echo "Please enter 'D' to delete, 'S' to skip, or 'Q' to quit."
                    ;;
            esac
        done
    else
        echo "'lightning_logs' folder does not exist in $1. Continuing..."
    fi
}

# PIPER_PATH should be inferred automatically from BIN_DIR provided that
# your venv folder is located in /piper/src/python
# Otherwise, you can manually add the path below

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
echo "BIN_DIR = '$BIN_DIR'"

# If PIPER_PATH is still empty, attempt to infer it from BIN_DIR
if [ -z "$PIPER_PATH" ]; then
    # Extract /path/to/piper/
    PIPER_PATH=$(echo "$BIN_DIR" | grep -oP "^.+?/piper/")
fi

DOJO_DIR=$(cat .DOJO_DIR)
echo "DOJO_DIR = '$DOJO_DIR'"

# Check if 'lightning_logs' folder exists in DOJO_DIR/training_folder
check_lightning_logs "$DOJO_DIR/training_folder/lightning_logs"

# Now you can continue with the rest of your script
cd "$PIPER_PATH"
python -m piper_train \
    --dataset-dir "$DOJO_DIR/training_folder/" \
    --accelerator gpu \
    --devices 1 \
    --batch-size 4 \
    --validation-split 0.0 \
    --num-test-examples 0 \
    --max_epochs 30000 \
    --resume_from_checkpoint "$DOJO_DIR/pretrained_tts_checkpoint/"*.ckpt \
    --checkpoint-epochs 1 \
    --precision 32

exit 0

