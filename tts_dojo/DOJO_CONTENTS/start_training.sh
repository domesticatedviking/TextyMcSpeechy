#!/bin/bash

if [ ! -e ".BIN_DIR" ]; then
   echo ".BIN_DIR not present"
   sleep 1
fi

BIN_DIR=$(cat ".BIN_DIR")


if [ ! -e "$BIN_DIR/activate" ]; then
   echo "Can't find venv in $BIN_DIR."
   sleep 3
fi

if [ -e ".DOJO_DIR" ]; then   # running from voicename_dojo
    DOJO_DIR=$(cat ".DOJO_DIR")
else
    echo ".DOJO_DIR not found.   Exiting"
    exit 1
fi


color_file="./scripts/.colors"
if [ -e $color_file ]; then
    source $color_file
else
    echo "$0 - color_file not found"
    echo "     expected location: $settings_file"
    echo 
    echo "exiting"
    exit 1
fi


this_dir=$(pwd)
dir_only=$(basename "$this_dir")

if [ $dir_only = "DOJO_CONTENTS" ]; then
   echo -e "${RED}The DOJO_CONTENTS folder is used as a template for other dojos."
   echo -e "You should not run any scripts inside of DOJO_CONTENTS"
   echo 
   echo -e "Instead, run 'newdojo.sh' <voice name> to create a new dojo"
   echo -e "and train your models in that folder." 
   echo
   echo -e "Exiting${RESET}"
   exit 1
fi

if [[ -n "$VIRTUAL_ENV" ]]; then
    echo
    echo "OK    --  Virtual environment is active in  $VIRTUAL_ENV"
    
elif [ -e "$BIN_DIR/activate" ]; then
   echo "Activating virtual environment."
   source $BIN_DIR/activate
else
    echo "ERROR --  No python virtual environment was found."
    echo
    echo "Exiting."
    exit 1
fi



# Exit immediately if any command returns a nonzero exit code
set -e


# Function to check the return code of the last executed command
check_exit_status() {
    if [ $? -ne 0 ]; then
        echo "${RED}An error occurred. start_training.sh is stopping.${RESET}"
        exit 1
    fi
}


# Function to calculate the total size of a directory in GB
bad_dir_size_in_gb() {
    local dir_path="$1"
    if [ -d "$dir_path" ]; then
        local size_in_kb=$(du -sk "$dir_path" | cut -f1)
        local size_in_gb=$(echo "scale=2; $size_in_kb / 1024 / 1024" | bc)
        echo "$size_in_gb"
    else
        echo "Invalid directory"
    fi
}

dir_size_in_gb() {
    local dir_path="$1"
    if [ -d "$dir_path" ]; then
        local size_in_kb=$(du -sk "$dir_path" | cut -f1)
        local size_in_gb=$(echo "scale=2; $size_in_kb / 1024 / 1024" | bc)
        printf "%7.2f\n" "$size_in_gb"
    else
        echo "Invalid directory"
    fi
}


clear
echo -e "      ${BOLD_PURPLE}TextyMcspeechy TTS Dojo${RESET}"
echo
echo -e "      The dataset in the ${CYAN}target_voice_dataset${RESET} directory will be analyzed and cleaned before training."
echo -e "      It is ${BOLD_YELLOW}highly recommended ${RESET}that you keep backup copies all of your files."
echo -e "      If you choose to use this tool, you do so at your own risk."
echo 
echo -ne "      ${YELLOW}Do you want to proceed? (y/n)  ${RESET}"
read choice

# Check the user's response
if [[ "$choice" = [Nn]* ]]; then
    echo "     Exiting."
    exit 1
fi


echo -e "\nrunning scripts/sanitize_dataset.sh"
sleep 1
clear

bash ./scripts/sanitize_dataset.sh
check_exit_status

clear

echo -e "\nrunning scripts/preprocess_dataset.sh"
echo

# Execute the preprocessing script
bash ./scripts/preprocess_dataset.sh
check_exit_status  # Check if the last command failed


bash ./scripts/train.sh
check_exit_status  # Check if training script failed
clear
echo "Thank you for using TextyMcSpeechy."
echo

echo -e "Reminder: There are currently ${CYAN}$(dir_size_in_gb $DOJO_DIR) GB${RESET} of files in ${GREEN}$(basename $DOJO_DIR)${RESET}:"
echo -e "${CYAN}$(dir_size_in_gb $DOJO_DIR/voice_checkpoints) GB in ${GREEN}voice_checkpoints${RESET}"
echo -e "${CYAN}$(dir_size_in_gb $DOJO_DIR/tts_voices) GB in ${GREEN}tts_voices${RESET}"
echo -e "${CYAN}$(dir_size_in_gb $DOJO_DIR/archived_checkpoints) GB in ${GREEN}archived_checkpoints${RESET}"
echo -e "${CYAN}$(dir_size_in_gb $DOJO_DIR/archived_tts_voices) GB in ${GREEN}archived_tts_voices${RESET}"
echo
echo -e "Please remember to delete any files you don't need."

      
echo
exit 0




