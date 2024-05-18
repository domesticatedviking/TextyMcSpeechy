#!/bin/bash
DOJO_DIR=$(cat .DOJO_DIR)
#echo "DOJO_DIR = '$DOJO_DIR'"

archive_checkpoints(){
# copy all ckpt files out of lightning logs folder/
cp $DOJO_DIR/training_folder/lightning_logs/version_0/checkpoints/*.ckpt $DOJO_DIR/voice_checkpoints

}



# Function to check and possibly delete the 'lightning_logs' folder
check_lightning_logs() {
    if [ -d "$1" ]; then
        echo
        echo "Previous training data was found in training_folder/lightning_logs."
	echo "This could be the result of a previous training attempt"
	echo
        echo "Options: [D]elete old data and start training," 
        echo "         [A]rchive old checkpoint files in voice_checkpoints directory"
        echo "         [S]kip training and attempt to package your TTS model"
        echo "         [Q]uit"
	echo

        while true; do
            read -p "What would you like to do? (D/A/S/Q): " option
            case "$option" in
                [Dd]* )
                    rm -rf "$1"
                    echo "'lightning_logs' folder deleted."
                    break
                    ;;
                [Aa]* )
                    echo "Copying checkpoint files to $DOJO_DIR/voice_checkpoints"
                    archive_checkpoints
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

PIPER_PATH=$(cat .PIPER_PATH)
#echo "PIPER_PATH = '$PIPER_PATH'"



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
#echo "BIN_DIR = '$BIN_DIR'"

# If PIPER_PATH is still empty, attempt to infer it from BIN_DIR
if [ -z "$PIPER_PATH" ]; then
    # Extract /path/to/piper/
    PIPER_PATH=$(echo "$BIN_DIR" | grep -oP "^.+?/piper/")
fi



# Check if 'lightning_logs' folder exists in DOJO_DIR/training_folder
check_lightning_logs "$DOJO_DIR/training_folder/lightning_logs"

# Now you can continue with the rest of your script
#cd "$PIPER_PATH"
#'python -m piper_train \
#    --dataset-dir "$DOJO_DIR/training_folder/" \
#    --accelerator gpu \
#    --devices 1 \
#    --batch-size 4 \
#    --validation-split 0.0 \
#    --num-test-examples 0 \
#    --max_epochs 30000 \
#    --resume_from_checkpoint "$DOJO_DIR/pretrained_tts_checkpoint/"*.ckpt \
#    --checkpoint-epochs 1 \
#    --precision 32' | tee >(grep "epoch") &

cd $DOJO_DIR/scripts
tmux new-session -s training -d
tmux send-keys -t training "./pipertraining.sh" Enter
tmux pipe-pane -t training 'exec tee ./training_output.txt'
tmux split-window -v -t training
tmux send-keys -t training "tmux resize-pane -t 0.0 -U 15" Enter
tmux send-keys -t training "tmux set -g pane-border-status top" Enter
tmux send-keys -t training "clear" Enter
tmux split-window -v -t training
tmux send-keys -t training "tmux resize-pane -t 0.1 -U 10" Enter
tmux send-keys -t 0.1 "cd ${DOJO_DIR} && bash view_training_progress.sh" Enter
tmux select-pane -t 0.0 -T 'PIPER TRAINING RAW OUTPUT'
tmux select-pane -t 0.1 -T 'TENSORBOARD SERVER'
tmux select-pane -t 0.2 -T 'USER CONSOLE -'
tmux send-keys -t 0.2 "clear" Enter
tmux send-keys -t 0.2 "bash .tmux_training_guide.sh" Enter
clear

tmux a




exit 0

