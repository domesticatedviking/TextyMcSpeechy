
#!/bin/bash

# Prompt the user with a yes/no question
clear
echo "./scripts/1_preprocess.sh - Preprocessing starting"
echo
bash ./scripts/1_preprocess.sh

echo "FINISHED PREPROCESSING SUCCESSFULLY"  
echo
echo "./scripts/2_training.sh"
echo
echo " IMPORTANT - PLEASE READ "
echo 
echo " Training is about to begin.  You will need to manually end it when you think it's done by pushing <CTRL> C."
echo 
echo " It is up to you to decide how many epochs you want to train for"
echo
echo " Once training is started, you can monitor the training process by"
echo " running "check_training_progress.sh" in another terminal window."
echo
echo
read -p "  Begin training (y/n): " choice

# Check the user's response
if [[ "$choice" == [Yy]* ]]; then
    echo "OK.  Beginning training"
    bash ./scripts/2_training.sh
else
    echo "Exiting."
    exit 3
fi

echo "./scripts/3_finish_voice.sh"
echo
bash ./scripts/3_finish_voice.sh 
