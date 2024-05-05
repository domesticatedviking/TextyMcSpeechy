#!/bin/bash

# Exit immediately if any command returns a nonzero exit code
set -e

# Function to check the return code of the last executed command
check_exit_status() {
    if [ $? -ne 0 ]; then
        echo "An error occurred. Stopping script."
        exit 1
    fi
}

clear
echo "./scripts/1_preprocess.sh - Preprocessing starting"
echo

# Execute the preprocessing script
bash ./scripts/1_preprocess.sh
check_exit_status  # Check if the last command failed

echo "FINISHED PREPROCESSING SUCCESSFULLY"  
echo
echo "./scripts/2_training.sh"
echo
echo " IMPORTANT - PLEASE READ "
echo 
echo " Training is about to begin. You will need to manually end it when you think it's done by pressing <CTRL> + C."
echo 
echo " It is up to you to decide how many epochs you want to train for."
echo
echo " Once training is started, you can monitor the training process by"
echo " running 'check_training_progress.sh' in another terminal window."
echo
echo
read -p "  Begin training (y/n): " choice

# Check the user's response
if [[ "$choice" == [Yy]* ]]; then
    echo "OK. Beginning training"
    bash ./scripts/2_training.sh
    check_exit_status  # Check if training script failed
else
    echo "Exiting."
    exit 3
fi

echo "./scripts/3_finish_voice.sh"
echo

# Execute the script to finish voice
bash ./scripts/3_finish_voice.sh
check_exit_status  # Check if the finishing script failed

