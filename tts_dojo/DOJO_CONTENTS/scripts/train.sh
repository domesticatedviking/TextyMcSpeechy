#!/bin/bash
trap "kill 0" SIGINT
DOJO_DIR=$(cat .DOJO_DIR)
#echo "DOJO_DIR = '$DOJO_DIR'"

if [ -e ".DOJO_DIR" ]; then   # running from voicename_dojo
    DOJO_DIR=$(cat ".DOJO_DIR")
else
    echo ".DOJO_DIR not found.   Exiting"
    exit 1
fi



if [ ! -e ".BIN_DIR" ]; then
   echo ".BIN_DIR not present"
   sleep 1
fi

BIN_DIR=$(cat ".BIN_DIR")


if [ ! -e "$BIN_DIR/activate" ]; then
   echo "Can't find venv in $BIN_DIR."
   sleep 3
fi

if [[ -n "$VIRTUAL_ENV" ]]; then
    :
    #echo "OK    --  Virtual environment is active in  $VIRTUAL_ENV"
    
elif [ -e "$BIN_DIR/activate" ]; then
   echo "Activating virtual environment."
   source $BIN_DIR/activate
else
    echo "ERROR --  No python virtual environment was found."
    echo
    echo "Exiting."
    exit 1
fi




source $DOJO_DIR/scripts/SETTINGS.txt
source $DOJO_DIR/scripts/.colors

VENV_ACTIVATE="$BIN_DIR/activate"
OVERRIDE_DIRNAME="starting_checkpoint_override"


VOICE_CHECKPOINTS_DIRNAME=${SETTINGS_VOICE_CHECKPOINT_DIRNAME:-"voice_checkpoints"}
SAVED_CHECKPOINTS="$DOJO_DIR/$VOICE_CHECKPOINTS_DIRNAME"
if ! [ -d $SAVED_CHECKPOINTS ]; then
   echo "Error. Required directory does not exist: $SAVED_CHECKPOINTS  Exiting."
   exit 1
fi   

TTS_VOICES_DIRNAME="tts_voices"
TTS_VOICES="$DOJO_DIR/$TTS_VOICES_DIRNAME"
if ! [ -d $TTS_VOICES ]; then
   echo "Error. Required directory does not exist: $TTS_VOICES  Exiting."
   exit 1
fi   


PRETRAINED_TTS_CHECKPOINT_DIRNAME="pretrained_tts_checkpoint"


ARCHIVED_CHECKPOINTS_DIRNAME="archived_checkpoints"
ARCHIVED_CHECKPOINTS="$DOJO_DIR/$ARCHIVED_CHECKPOINTS_DIRNAME"
if [ ! -d "$ARCHIVED_CHECKPOINTS" ]; then
   echo " $ARCHIVED_CHECKPOINTS directory does not exist.  Exiting."
   exit 1
fi

ARCHIVED_TTS_VOICES_DIRNAME="archived_tts_voices"   
ARCHIVED_TTS_VOICES="$DOJO_DIR/$ARCHIVED_TTS_VOICES_DIRNAME"
if ! [ -d $ARCHIVED_TTS_VOICES ]; then
   echo "Error. Required directory does not exist: $ARCHIVED_TTS_VOICES  Exiting."
   exit 1
fi   



# init global vars
highest_saved_epoch_ckpt=""
highest_saved_epoch=""
saved_ckpt_size=""
has_saved_checkpoints=false
has_override=false
override_epoch=""
override_checkpoint_file=""
highest_saved_checkpoint_file=""
trainer_starting_checkpoint=""
pretrained_epoch=""
has_pretrained_checkpoint=false
resume_or_restart=""
checkpoint_recommendation=""
voice_dir_count=0

# Delete lightning logs folder from last run
LIGHTNING_LOGS_LOCATION="${DOJO_DIR}/training_folder/lightning_logs"
cp "$LIGHTNING_LOGS_LOCATION=/version_0/checkpoints/*.ckpt" "$dojo_dir/$VOICE_CHECKPOINTS_DIRNAME/" >/dev/null 2>&1
sleep 1
rm -r $LIGHTNING_LOGS_LOCATION


PIPER_PATH=$(cat .PIPER_PATH)

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



BIN_DIR=$(cat .BIN_DIR)
#echo "BIN_DIR = '$BIN_DIR'"

# If PIPER_PATH is still empty, attempt to infer it from BIN_DIR
if [ -z "$PIPER_PATH" ]; then
    # Extract /path/to/piper/
    PIPER_PATH=$(echo "$BIN_DIR" | grep -oP "^.+?/piper/")
fi



clear


calculate_directory_size() {
    if [ -d "$1" ]; then
        # Calculate the total size in bytes
        size_in_bytes=$(du -sb "$1" | cut -f1)
        # Convert bytes to GB (1 GB = 1073741824 bytes)
        size_in_gb=$(echo "scale=2; $size_in_bytes / 1073741824" | bc)
        echo "$size_in_gb GB"
    else
        echo "-1"
    fi
}

count_directories() {
    local dir_count=0   
    if [ -d "$1" ]; then
        dir_count=$(find "$1" -mindepth 1 -maxdepth 1 -type d | wc -l)
        echo "$dir_count"
    else
        echo "-1"
    fi
}

count_ckpt_files() {
    local directory=$1

    if [[ ! -d "$directory" ]]; then
        echo "Directory does not exist: $directory"
        return 1
    fi

    local count=$(find "$directory" -maxdepth 1 -name '*.ckpt' | wc -l)

    echo "$count"
}

get_total_ckpt_size_gb() {
    local directory=$1

    if [[ ! -d "$directory" ]]; then
        echo "Directory does not exist: $directory"
        return 1
    fi

    local total_size_kb=$(find "$directory" -name '*.ckpt' -exec du -k {} + | awk '{sum += $1} END {print sum}')

    if [[ -z "$total_size_kb" ]]; then
        echo "No .ckpt files found in the directory: $directory"
        return 1
    fi

    local total_size_gb=$(echo "scale=2; $total_size_kb / 1024 / 1024" | bc)

    echo "$total_size_gb GB"
}

get_epoch_number() {
    local checkpoint_file=$1

    if [[ ! -f "$checkpoint_file" ]]; then
        echo "File does not exist: $checkpoint_file"
        return 1
    fi

    local epoch_number=$(echo "$checkpoint_file" | awk -F'[=-]' '{print $2}')

    if [[ -z "$epoch_number" ]]; then
        echo "No epoch number found in the file name: $checkpoint_file"
        return 1
    fi

    echo "$epoch_number"
}

get_highest_epoch_ckpt() {
    # function to return highest epoch of checkpoint file in any directory.
    local checkpoint_dir=$1

    if [[ ! -d "$checkpoint_dir" ]]; then
        echo "Directory does not exist: $checkpoint_dir"
        return 1
    fi

    local highest_epoch_ckpt=$(ls "$checkpoint_dir"/*.ckpt 2>/dev/null | \
        awk -F'[-=]' '{print $2, $0}' | \
        sort -nr | \
        head -n 1 | \
        awk '{print $2}')

    if [[ -z "$highest_epoch_ckpt" ]]; then
        echo "No .ckpt files found in the directory: $checkpoint_dir"
        return 1
    fi

    echo "$highest_epoch_ckpt"
}

ask_about_resuming_or_restarting(){
    local choice=""
    local quick_choice="1"
    #must return a value for resume_or_restart = [resume, restart]
    echo
    echo
    echo -e "        This dojo contains saved checkpoints from previous training runs."
    echo -e "        Please select an option:"
    echo 
    echo -e "        1. Resume from highest saved checkpoint file (epoch $highest_saved_epoch) (recommended)"  
    echo -e "        2. Restart training using original pretrained TTS model (epoch $pretrained_epoch)"
    echo -e "        3. Quit"
    echo
   echo -ne "        What would you like to do (1-3):  "
    read choice
    # substitute action if user only pushes enter. Makes relaunching faster
    if [[ "$choice" = "" ]]; then
        choice=$quick_choice
        echo "Quick choice: $quick_choice"
    fi
    
    # Check the user's response
    if [[ "$choice" = "1" ]]; then
        echo "Training will be resumed from saved checkpoint (epoch $highest_saved_epoch)"
        resume_or_restart="resume"
    elif [[ "$choice" = "2" ]]; then
        echo "Training will restart using pretrained tts checkpoint (epoch $pretrained_epoch)"
        resume_or_restart="restart"
    elif [[ "$choice" = "3" ]]; then
        echo "Exiting."
        exit 1
    fi
}

#!/bin/bash

# Generalized confirmation function
ask_confirmation() {
    local prompt_message=$1
    local yes_action=$2
    local no_action=$3
    local quick_answer=${4:-"n"} #answer no in response to enter key if no parameter given
    local do_it=false
        

    while true; do
        read -p "$prompt_message (y/n): " answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]') # Convert to lowercase

        if [[ -z "$answer" ]]; then
            answer=$quick_answer
        fi

        if [[ "$answer" == "y" || "$answer" == "yes" ]]; then
            do_it=true
            break
        elif [[ "$answer" == "n" || "$answer" == "no" ]]; then
            do_it=false
            break
        else
            echo "Invalid input. Please answer with 'y' or 'n'."
        fi
    done

    if [[ "$do_it" == true ]]; then 
        eval "$yes_action"
    else
        eval "$no_action"
    fi
}

# Specific actions for each scenario
delete_voice_checkpoints_yes() {
    echo "Removing saved voice checkpoints."
    cd $SAVED_CHECKPOINTS
    rm *.ckpt
    cd ..
    sleep 2
}

delete_voice_checkpoints_no() {
    echo "Not deleting voice checkpoints."
    sleep 2
}

archive_voice_checkpoints_yes() {
    echo "Archiving voice checkpoints"
    mv $SAVED_CHECKPOINTS/*.ckpt $ARCHIVED_CHECKPOINTS/
    sleep 2
}

archive_voice_checkpoints_no() {
    echo "Not archiving voice checkpoints."
    sleep 2
}

archive_tts_voices_yes() {
    echo "Archiving tts voices"
    mv $TTS_VOICES/* $ARCHIVED_TTS_VOICES
    sleep 2
}

archive_tts_voices_no() {
    echo "Not archiving tts voices."
    sleep 2
}

delete_tts_voices_yes() {
    echo "Deleting all voice models in $TTS_VOICES_DIRNAME"
    rm -r $TTS_VOICES/*
    sleep 2
}

delete_tts_voices_no() {
    echo "Not deleting voice models."
    sleep 2
}

accept_settings_yes() {
    echo "Settings accepted"
    clear
} 

accept_settings_no(){
    echo "Exiting."
    exit 1
}

# Example usage for each scenario
delete_voice_checkpoints() {
    ask_confirmation "Are you sure you want to delete voice checkpoints?" "delete_voice_checkpoints_yes" "delete_voice_checkpoints_no"
}

archive_voice_checkpoints() {
    ask_confirmation "Are you sure you want to archive voice checkpoints?" "archive_voice_checkpoints_yes" "archive_voice_checkpoints_no"
}

archive_tts_voices() {
    ask_confirmation "Are you sure you want to archive tts voices?" "archive_tts_voices_yes" "archive_tts_voices_no"
}

delete_tts_voices() {
    ask_confirmation "Are you sure you want to delete all subfolders in tts_voices?" "delete_tts_voices_yes" "delete_tts_voices_no"
}

accept_settings() {
    echo
    ask_confirmation "        Are you ready to start training?" "accept_settings_yes" "accept_settings_no" "y"
}


ask_about_existing_checkpoints(){
    local choice=""
    local quick_choice="1" 
    echo
    echo
    echo
    echo
    echo -e "    There are $saved_ckpt_count checkpoint files saved in $VOICE_CHECKPOINTS_DIRNAME"
    echo -e "    These files occupy $saved_ckpt_size on disk"
    echo
    echo -e "    Please note that training will *not* overwrite any files left in this folder"
    echo -e 
    echo
    echo -e "        Please select an option:"
    echo
    echo -e "        1. Proceed without deleting the files. "
    echo -e "        2. Archive all checkpoint files to $ARCHIVED_CHECKPOINTS_DIRNAME"
    echo -e "        3. Delete all checkpoint files in $VOICE_CHECKPOINTS_DIRNAME (recommended)"
    echo -e "        4. Quit."
    echo
   echo -ne "        What would you like to do (1-4):  "
    
    read choice
    # substitute action if user only pushes enter. Makes relaunching faster
    if [[ "$choice" = "" ]]; then
        choice=$quick_choice
        echo "Quick choice: $quick_choice"
    fi
    
    # Check the user's response
    if [[ "$choice" = "1" ]]; then
        echo "Proceeding without deleting checkpoint files"
        clear
    elif [[ "$choice" = "2" ]]; then
        archive_voice_checkpoints
        clear
    elif [[ "$choice" = "3" ]]; then
        delete_voice_checkpoints
        clear
    elif [[ "$choice" = "4" ]]; then
        exit 1
    fi
}

update_voice_dir_count(){
    voice_dir_count=$(count_directories $DOJO_DIR/$TTS_VOICES_DIRNAME)
}



ask_about_existing_voices(){
    local choice=""
    local quick_choice="1" 
    local voice_dir_size_gb=$(calculate_directory_size $DOJO_DIR/$TTS_VOICES_DIRNAME)
    echo
    echo
    echo -e 
    echo -e "        There are ${voice_dir_count} ONNX voice models saved in $TTS_VOICES_DIRNAME"
    echo -e "        These files occupy $voice_dir_size_gb on disk"
    echo
    echo -e "        Training will *not* overwrite any files left in this folder"
    echo
    echo
    echo -e "        Please select an option:"
    echo -e 
    echo -e "            1. Leave the voices where they are."
    echo -e "            2. Move voices to archived_voices (recommended)"
    echo -e "            3. Delete all voices in '$TTS_VOICES_DIRNAME'."
    echo -e "            4. Quit"
    echo
   echo -ne "            What would you like to do (1-4): "
    read choice
    # substitute action if user only pushes enter. Makes relaunching faster
    if [[ "$choice" = "" ]]; then
        choice=$quick_choice
        echo "Quick choice: $quick_choice"
    fi
    if [[ "$choice" = "1" ]]; then
        echo "Leaving TTS voices as is"

    elif [[ "$choice" = "2" ]]; then
        archive_tts_voices

    elif [[ "$choice" = "3" ]]; then
        delete_tts_voices
    elif [[ "$choice" = "4" ]]  ; then
        exit 1
    fi
 

}

check_manual_override_dir(){
local override_ckpt=$(get_highest_epoch_ckpt "$DOJO_DIR/$OVERRIDE_DIRNAME")
if [[ -f "$override_ckpt" ]]; then
        override_epoch=$(get_epoch_number $override_ckpt)
        clear
        echo
        echo
        echo -e "${RED}STARTING CHECKPOINT HAS BEEN MANUALLY OVERRIDDEN BY USER${RESET}"
        echo -e "        file:  $(basename $override_ckpt)"
        echo -e "  located in:  $DOJO_DIR/$OVERRIDE_DIRNAME"
        echo -e "       epoch:  $override_epoch"
        echo -e "${RED}to cancel override, remove all ${YELLOW}.ckpt${RED} files from ${YELLOW}$OVERRIDE_DIRNAME${RESET}"
        echo
        echo -ne "${CYAN}Press ENTER to begin training${RESET}"
        read
        has_override=true
        override_checkpoint_file=$override_ckpt
fi


}


find_highest_saved_epoch(){
        highest_saved_epoch_ckpt=$(get_highest_epoch_ckpt "$DOJO_DIR/$VOICE_CHECKPOINTS_DIRNAME")
        
        if [[ -f "$highest_saved_epoch_ckpt" ]] && [ $saved_ckpt_count -gt 0 ];  then
            has_saved_checkpoints=true
            highest_saved_epoch=$(get_epoch_number $highest_saved_epoch_ckpt)
            saved_ckpt_size=$(get_total_ckpt_size_gb "$DOJO_DIR/$VOICE_CHECKPOINTS_DIRNAME")
            echo
            echo "    Found saved checkpoint files in '$VOICE_CHECKPOINTS_DIRNAME'"
            echo "            Number of saved checkpoints: $saved_ckpt_count"
            echo "        Total size of saved checkpoints: $saved_ckpt_size"
            echo "          Highest saved epoch available: $highest_saved_epoch"
            echo
            
       else
           echo " No saved checkpoints found in $VOICE_CHECKPOINTS_DIRNAME "
       fi
}

check_pretrained_ckpt(){
    pretrained_tts_checkpoint=$(get_highest_epoch_ckpt "$DOJO_DIR/$PRETRAINED_TTS_CHECKPOINT_DIRNAME")
    if [[ -f "$pretrained_tts_checkpoint" ]]; then
        has_pretrained_checkpoint=true
        pretrained_epoch=$(get_epoch_number $pretrained_tts_checkpoint)
    fi
}
update_saved_ckpt_count(){
    saved_ckpt_count=$(count_ckpt_files "$DOJO_DIR/$VOICE_CHECKPOINTS_DIRNAME")
}

get_starting_checkpoint_recommendation(){

check_manual_override_dir # sets value of $has_override and $override_checkpoint_fle

# If no override set, continue to search for starting checkpoint.
if [ "$has_override" = false ]; then  

    #get info about pretrained TTS checkpoint (typically loaded by add_my_files.sh)
    check_pretrained_ckpt  #sets value of has_pretrained_ckpt
    
    # count saved checkpoint files
    update_saved_ckpt_count

    # find the one with the highest epoch
    if [[ $saved_ckpt_count -gt "0" ]]; then
        find_highest_saved_epoch
    fi

   
    if [[ "$has_saved_checkpoints" = true ]]; then
        echo "                 Highest saved epoch is: $highest_saved_epoch"
    fi

    if [[ "$has_pretrained_checkpoint" = true ]]; then
        echo "     Pretrained tts checkpoint epoch is: $pretrained_epoch"
    fi
    
    if [[ $highest_saved_epoch -gt $pretrained_epoch ]]; then
        checkpoint_recommendation="saved"
    else
        checkpoint_recommendation="pretrained"
    fi
else
    checkpoint_recommendation="override"
fi



}

start_tmux_layout(){
    
    tmux new-session -s training -d # start tmux session called "training" but don't join it yet
    tmux set-option -g mouse on     # turn on mouse scrolling
    tmux send-keys -t training "tmux set -g pane-border-status top" Enter     # Turn on pane labels

    # only run this if the output from the training script is needed elsewhere 
    #tmux pipe-pane -t training 'exec tee ./training_output.txt'

    # split screen into two rows
    tmux split-window -v -t training
    tmux send-keys -t training "tmux resize-pane -t 0.0 -U 24" Enter  # shrink the top pane 
    tmux send-keys -t training "tmux resize-pane -t 0.0 -R 42" Enter
    #shrink the top pane

    tmux split-window -h -t 0.0     # split top row into 2 columns


    #split the bottom pane into 2 columns horizontally and resize it.
    tmux split-window -h -t 0.2
    tmux send-keys -t training "tmux resize-pane -t 0.2 -U 24" Enter  # shrink the top pane 


    tmux split-window -v -t 0.2
    #tmux send-keys -t training "tmux resize-pane -t 0.2 -L 25" Enter
    #tmux send-keys -t training "tmux resize-pane -t 0.2 -L 15" Enter
    
    #tmux split-window -v -t 0.3
    #tmux split-window -v -t 0.2
    tmux split-window -v -t 0.3
    
    tmux send-keys -t training "tmux resize-pane -t $TMUX_CONTROL_PANE -U 10" Enter  # shrink the top pane 
    # label each pane



    
    tmux select-pane -t "${TMUX_TRAINING_PANE:-0.0}" -T "${TMUX_TRAINING_PANE_TITLE:-'PIPER TRAINING RAW OUTPUT'}"
    tmux select-pane -t "${TMUX_TENSORBOARD_PANE:-0.1}" -T "${TMUX_TENSORBOARD_PANE_TITLE:-'TENSORBOARD SERVER'}"
    tmux select-pane -t "${TMUX_EXPORTER_PANE:-0.2}" -T "${TMUX_EXPORTER_PANE_TITLE:-'VOICE EXPORTER'}"
    tmux select-pane -t "${TMUX_GRABBER_PANE:-0.3}" -T "${TMUX_GRABBER_PANE_TITLE:-'CHECKPOINT GRABBER'}"
    tmux select-pane -t "${TMUX_CONTROL_PANE:-0.4}" -T "${TMUX_CONTROL_PANE_TITLE:-'CONTROL CONSOLE'}"
    tmux select-pane -t "${TMUX_TESTER_PANE:-0.5}" -T "${TMUX_TESTER_PANE_TITLE:-'VOICE TESTER'}"

}


start_tmux_processes(){
    # start the training script in pane 0.0
    
    tmux send-keys -t "${TMUX_TRAINING_PANE:-0.0}" "source $VENV_ACTIVATE" Enter
    tmux send-keys -t "${TMUX_TRAINING_PANE:-0.0}" "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/erik/code/testmultilang/TextyMcSpeechy/piper/src/python/.venv/lib64/python3.10/site-packages/nvidia/cublas/lib:/home/erik/code/testmultilang/TextyMcSpeechy/piper/src/python/.venv/lib64/python3.10/site-packages/nvidia/cudnn/lib" Enter
    tmux send-keys -t "${TMUX_TRAINING_PANE:-0.0}" "utils/piper_training.sh $trainer_starting_checkpoint" Enter

    tmux send-keys -t "${TMUX_TENSORBOARD_PANE:-0.1}" "source $VENV_ACTIVATE" Enter
    tmux send-keys -t "${TMUX_TENSORBOARD_PANE:-0.1}" "bash utils/run_tensorboard_server.sh" Enter

    tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.2}" "source $VENV_ACTIVATE" Enter
    tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.2}" "clear && echo 'Ready to export voice models' && read " Enter

    tmux send-keys -t "${TMUX_GRABBER_PANE:-0.3}" "source $VENV_ACTIVATE" Enter
    tmux send-keys -t "${TMUX_GRABBER_PANE:-0.3}" "bash utils/checkpoint_grabber.sh --save_every ${AUTO_SAVE_EVERY_NTH_CHECKPOINT_FILE} $DOJO_DIR/voice_checkpoints" Enter
    
    # run control console
    tmux send-keys -t "${TMUX_CONTROL_PANE:-0.5}" "cd $DOJO_DIR/scripts/ && bash utils/_control_console.sh" Enter
    
    # run voice tester
    tmux send-keys -t ${TMUX_TESTER_PANE:-"0.4"} "source $VENV_ACTIVATE" Enter
    tmux send-keys -t ${TMUX_TESTER_PANE:-"0.4"} "bash voice_tester.sh" Enter
    

    
}


confirm_preferences(){
    echo -e "${GREEN}Training configuration from scripts/SETTINGS.txt:${RESET}"
    echo
    echo -e "        ${PURPLE}CHECKPOINT GRABBER SETTINGS (checkpoint_grabber.sh)${RESET}"
    echo -e "                         Save checkpoint every: ${CYAN}$AUTO_SAVE_EVERY_NTH_CHECKPOINT_FILE${RESET} epoch(s)."
    echo -e "            Abort if below minimum drive space: ${CYAN}$MINIMUM_DRIVE_SPACE_GB${RESET} GB"
    echo -e "             warn about low drive space within: ${CYAN}$DRIVE_SPACE_WARNING_THRESHOLD_GB${RESET} GB of minimum"
    echo 
    echo -e "        ${PURPLE}PIPER TRAINING SETTINGS (piper_train)${RESET}"
    echo -e "                                  --batch-size: ${CYAN}$PIPER_BATCH_SIZE${RESET}"
    echo -e "                           --checkpoint-epochs: ${CYAN}$PIPER_SAVE_CHECKPOINT_EVERY_N_EPOCHS${RESET}"

   
}

show_warning(){
echo
echo
echo
    echo -e "     ${YELLOW}You are about to enter the TTS training dojo.${YELLOW} "
    echo
    echo -e "     ${RED}WARNING: The scripts in the dojo are capable of creating large numbers of very large files."
    echo -e "              Each checkpoint file that you save is over ${CYAN}800MB${RED} in size.${RESET}"
    echo
    echo -e "     ${YELLOW}The dojo will launch multiple processes in a tmux session named 'training'."
    echo 
    echo -e "               ${GREEN}IMPORTANT:  write this command down!${RESET}"
    echo
    echo -e "               ${CYAN}tmux kill-session${RESET}"
    echo 
    echo -e "               ${YELLOW}if you lose access to the dojo controls, this command will "
    echo -e "               ${YELLOW}shut down the training process from any terminal window."
    echo
echo
}

# * MAIN PROGRAM **********************************************************
confirm_preferences
show_warning
echo -e "${GREEN}"
accept_settings
echo -e "${RESET}"

# choose between override, saved, and pretrained checkpoint options
get_starting_checkpoint_recommendation

if [[ "$has_override" = true ]]; then   # override will be used if present
    echo "Use manual override: $override_epoch"
    trainer_starting_checkpoint=$override_checkpoint_file
    read    
fi
    
# get user's choice about whether to resume training or restart it
if [[ "$checkpoint_recommendation" = "saved" ]] || [[ "$checkpoint_recommendation" = "pretrained" ]]; then  
   if [ $has_saved_checkpoints = "true" ]; then
       ask_about_resuming_or_restarting
        if [[ $resume_or_restart = "resume" ]]; then

            trainer_starting_checkpoint=$highest_saved_epoch_ckpt
        elif [[ $resume_or_restart = "restart" ]]; then

            trainer_starting_checkpoint=$pretrained_tts_checkpoint
        fi
   else # no saved checkpoints, no need to ask.
       echo "Dojo is clean, no previous checkpoints found"
       echo "Starting training with pretrained tts checkpoint file:"
       echo "   $pretrained_tts_checkpoint."
       trainer_starting_checkpoint=$pretrained_tts_checkpoint
   fi

fi



# when restarting training, ask what to do with files from previous runs.
if [[ $resume_or_restart = "restart" ]] || [[ "$has_override" = true ]] || [[ "$has_saved_checkpoints" = false ]] ; then
    update_voice_dir_count
    update_saved_ckpt_count
    
    if [ $saved_ckpt_count -gt 0 ]; then
        ask_about_existing_checkpoints
    fi
    if [ $voice_dir_count -gt 0 ]; then
        ask_about_existing_voices
    fi
fi           
clear
 echo -e "    Tips before training starts:"
 echo -e 
 echo -e "        1.  Depending on the size of your dataset, training could take several minutes to initialize.  Please be patient."
 echo
 echo -e "        2.  If you see ${CYAN}rank_zero_warn(${RESET} in the PIPER TRAINING RAW OUTPUT window, that's a good thing. Keep waiting."
 echo
 echo -e "        3.  It is normal to see a warning about a low number of workers. Resolving this would require changes to Piper's source code."
 echo
 echo -e "        4.  If you see an error related to ${CYAN}zip${RESET} files in PIPER TRAINING RAW OUTPUT, your starting checkpoint file is probably corrupted."
 echo -e "            This can be resolved either by restarting training or deleting the highest epoch checkpoint file from ${CYAN}$VOICE_CHECKPOINTS_DIRNAME${RESET}."
 echo
 echo -e "        5.  Pay close attention to the amount of storage your dojo is using.  This program will devour disk space if you save checkpoints too often."
 echo -e "            You are responsible for removing any files you don't want to keep."
 echo
 echo -e "        6.  Training runs in a multi-window terminal provided by ${CYAN}tmux${RESET}. The session name is ${CYAN}training${RESET}."
 echo
 echo -e "        7.  If you become detached from your tmux session or accidentally close the control panel, "
 echo -e "            you will need to use ${CYAN}tmux kill-session${RESET} to shut down training."
 echo
 echo -e "        8.  If you don't have a mouse, you can use ${GREEN}<CTRL> B${RESET} followed by an arrow key to change the active window."
 echo 
 echo
 echo -e "        Dojo setup is complete.   Press ${GREEN}<ENTER>${RESET} to begin training. "

read
cd $DOJO_DIR/scripts

start_tmux_layout
start_tmux_processes

# clear screen so that it won't have things on it when tmux exits.
clear

# join the running multi-shell tmux session.
tmux a

exit 0

