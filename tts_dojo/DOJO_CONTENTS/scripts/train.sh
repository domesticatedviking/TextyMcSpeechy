#!/bin/bash
trap "kill 0" SIGINT

# init path constants
DOJO_DIR="."  # run_training.sh runs this script from <voice>_dojo
DOJO_NAME=$(basename $PWD) # set dojo name used for building paths to <voice>_dojo
SETTINGS_FILE="scripts/SETTINGS.txt"
COLOR_FILE="scripts/.colors"
OVERRIDE_DIRNAME="starting_checkpoint_override"
VOICE_CHECKPOINTS_DIRNAME=${SETTINGS_VOICE_CHECKPOINT_DIRNAME:-"voice_checkpoints"}
SAVED_CHECKPOINTS="$DOJO_DIR/$VOICE_CHECKPOINTS_DIRNAME"
TTS_VOICES_DIRNAME="tts_voices"
TTS_VOICES="$DOJO_DIR/$TTS_VOICES_DIRNAME"
PRETRAINED_TTS_CHECKPOINT_DIRNAME="pretrained_tts_checkpoint"
ARCHIVED_CHECKPOINTS_DIRNAME="archived_checkpoints"
ARCHIVED_CHECKPOINTS="$DOJO_DIR/$ARCHIVED_CHECKPOINTS_DIRNAME"
ARCHIVED_TTS_VOICES_DIRNAME="archived_tts_voices"   
ARCHIVED_TTS_VOICES="$DOJO_DIR/$ARCHIVED_TTS_VOICES_DIRNAME"
LIGHTNING_LOGS_LOCATION="./training_folder/lightning_logs"
TRAIN_FROM_SCRATCH_FILE="./target_voice_dataset/.SCRATCH"

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

if [[ -f $TRAIN_FROM_SCRATCH_FILE ]]; then
    TRAIN_FROM_SCRATCH_STATE=$(cat $TRAIN_FROM_SCRATCH_FILE)
else
    echo "Warning: .SCRATCH file not found at: $TRAIN_FROM_SCRATCH_FILE ."
    read
fi



load_settings(){
# load training settings from SETTINGS_FILE
    if [ -e $SETTINGS_FILE ]; then
        source $SETTINGS_FILE
    else
        echo "$0 - settings not found"
        echo "     expected location: $SETTINGS_FILE"
        echo 
        echo "press <Enter> to exit"
        exit 1
    fi
}

load_colors(){
# load color codes from COLOR_FILE (eg scripts/.colors)
    if [ -e $COLOR_FILE ]; then
        source $COLOR_FILE
    else
        echo "$0 - COLOR_FILE not found"
        echo "     expected location: $settings_file"
        echo 
        echo "exiting"
        exit 1
    fi
}

verify_dirs_exist(){
# make sure <voice>_dojo has expected directories
    # verify SAVED_CHECKPOINTS dir (eg <voice>_dojo/voice_checkpoints) exists
    if ! [ -d ./$SAVED_CHECKPOINTS ]; then
       echo "Error. Required directory does not exist: $SAVED_CHECKPOINTS  Exiting."
       exit 1
    fi   

    # verify TTS_VOICES dir (eg <voice>_dojo/tts_voices) exists
    if ! [ -d ./$TTS_VOICES ]; then
       echo "Error. Required directory does not exist: $TTS_VOICES  Exiting."
       exit 1
    fi   

    # verify ARCHIVED_CHECKPOINTS dir (eg <voice>_dojo/archived_checkpoints) exists
    if [ ! -d "./$ARCHIVED_CHECKPOINTS" ]; then
       echo " $ARCHIVED_CHECKPOINTS directory does not exist.  Exiting."
       exit 1
    fi

    # verify ARCHIVED_TTS_VOICES dir (eg <voice>_dojo/archived_tts_voices) exists
    if ! [ -d ./$ARCHIVED_TTS_VOICES ]; then
       echo "Error. Required directory does not exist: $ARCHIVED_TTS_VOICES  Exiting."
       exit 1
    fi   
}

set_train_from_scratch(){
# link_dataset.sh configures a flag variable in <voice>_dojo/target_voice_dataset/.SCRATCH
# when it contains "true", piper_training.sh ignores any checkpoint files it is asked to use
# when it contains "resume" or "false" piper training processes those files.

    local scratch_setting=$1
    echo "$scratch_setting" > ${TRAIN_FROM_SCRATCH_FILE}

}



empty_checkpoint_folder(){
# Copy checkpoint file from prior run to allow user to resume from there and empty the folder 
    cp "$LIGHTNING_LOGS_LOCATION/version_0/checkpoints/*.ckpt" "./$VOICE_CHECKPOINTS_DIRNAME/" >/dev/null 2>&1
    sleep 1
    # note: this command is duplicated in piper_training.sh in order to allow quck restarts in the tmux session
    # (eg. recovering from a memory allocation error)
    rm -r $LIGHTNING_LOGS_LOCATION
}

calculate_directory_size() {
# return size of directory in GB
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
# return number of directories in specified directory
    local directory=$1
    local dir_count=0   
    if [ -d "$directory" ]; then
        dir_count=$(find "$directory" -mindepth 1 -maxdepth 1 -type d | wc -l)
        echo "$dir_count"
    else
        echo "-1"
    fi
}

count_ckpt_files() {
# return number of checkpoint files in specified directory
    local directory=$1
    if [[ ! -d "$directory" ]]; then
        echo "Directory does not exist: $directory"
        return 1
    fi
    local count=$(find "$directory" -maxdepth 1 -name '*.ckpt' | wc -l)
    echo "$count"
}


get_total_ckpt_size_gb() {
# returns total size in GB of checkpoint files in directory
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
# extracts epoch number from a checkpoint file name and returns it
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
# returns highest epoch number from a directory containing checkpoint files
    local checkpoint_dir=$1
    if [[ ! -d "$checkpoint_dir" ]]; then
        #echo "Directory does not exist: $checkpoint_dir"
        echo ""
        return 1
    fi
    local highest_epoch_ckpt=$(ls "$checkpoint_dir"/*.ckpt 2>/dev/null | \
        awk -F'[-=]' '{print $2, $0}' | \
        sort -nr | \
        head -n 1 | \
        awk '{print $2}')
    if [[ -z "$highest_epoch_ckpt" ]]; then
        #echo "No .ckpt files found in the directory: $checkpoint_dir"
        echo ""
        return 2
    fi
    echo "$highest_epoch_ckpt"
    return 0
}

make_docker_path(){
# converts a path from host to absolute path inside textymcspeechy-piper docker container
    local path="$1"
    echo "/app/tts_dojo/$DOJO_NAME/${path#*/tts_dojo}"
}

update_voice_dir_count(){
# updates global variable containing number of voices stored in dojo
    voice_dir_count=$(count_directories $DOJO_DIR/$TTS_VOICES_DIRNAME)
}

check_pretrained_ckpt(){
# locate highest epoch checkpoint stored in dojo 
    pretrained_tts_checkpoint=$(get_highest_epoch_ckpt "$PRETRAINED_TTS_CHECKPOINT_DIRNAME")
    if [[ -f "$pretrained_tts_checkpoint" ]]; then
        has_pretrained_checkpoint=true
        pretrained_epoch=$(get_epoch_number $pretrained_tts_checkpoint)
    fi
}

update_saved_ckpt_count(){
    saved_ckpt_count=$(count_ckpt_files "$VOICE_CHECKPOINTS_DIRNAME")
}

ask_about_resuming_or_restarting_from_scratch(){
# presents menu for dojos previously trained from scratch.
# must set global var resume_or_restart to either "resume" or "restart"
    local choice=""
    local quick_choice="1" # choice made if user presses "Enter" without choosing any option  
    echo
    echo
    echo -e "        This dojo contains saved checkpoints from previous training runs."
    echo -e "        Please select an option:"
    echo 
    echo -e "        1. Resume from highest saved checkpoint file (epoch $highest_saved_epoch) (recommended)"  
    echo -e "        2. Restart training from scratch"
    echo -e "        3. Quit"
    echo
    echo -ne "        What would you like to do (1-3):  "
    read choice
    
    # substitute action if user only pushes enter.
    if [[ "$choice" = "" ]]; then
        choice=$quick_choice
        echo "Quick choice: $quick_choice"
    fi
    
    # Act on user's response
    if [[ "$choice" = "1" ]]; then
        echo "Training will be resumed from saved checkpoint (epoch $highest_saved_epoch)"
        resume_or_restart="resume"
    elif [[ "$choice" = "2" ]]; then
        echo "Training will restart from scratch"
        resume_or_restart="restart"
    elif [[ "$choice" = "3" ]]; then
        echo "Exiting."
        exit 1
    fi
}


ask_about_resuming_or_restarting(){
# lets user decide whether they are starting a new training run or continuing a previous run
# must set global var resume_or_restart to either "resume" or "restart"
    local choice=""
    local quick_choice="1" # choice made if user presses "Enter" without choosing any option  
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
    
    # substitute action if user only pushes enter.
    if [[ "$choice" = "" ]]; then
        choice=$quick_choice
        echo "Quick choice: $quick_choice"
    fi
    
    # Act on user's response
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


ask_confirmation() {
# General user confirmation function
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
    local quick_choice="1" # default action if user presses enter without making a choice 
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


get_starting_checkpoint_recommendation(){
# Starting checkpoint could be one of three things, which are listed in order of priority. 
#     1. a manual override checkpoint file that the user has stored in <voice>_dojo/starting_checkpoint_override
#     2. a checkpoint file saved from a previous training run in <voice>_dojo/voice_checkpoints
#     3. a default pretrained checkpoint file located in tts_dojo/PRETRAINED_CHECKPOINTS

    check_manual_override_dir # sets value of $has_override and $override_checkpoint_fle

    
    if [ "$has_override" = false ]; then  
        # No file in override directory, continue to search for starting checkpoint. 
        check_pretrained_ckpt  #sets value of has_pretrained_ckpt
   
        # count saved checkpoint files
        update_saved_ckpt_count

        
        if [[ $saved_ckpt_count -gt "0" ]]; then
            # at least one checkpoint file is saved in this dojo, find the one trained the most. 
            find_highest_saved_epoch
        fi
        
        # Display epoch number of highest saved epoch in dojo if there are any
        if [[ "$has_saved_checkpoints" = true ]]; then            
            echo "                 Highest saved epoch is: $highest_saved_epoch"
        fi
        
        # Display epoch number of default checkpoint (in PRETRAINED_CHECKPONTS) if there is a file there
        if [[ "$has_pretrained_checkpoint" = true ]]; then
            echo "     Pretrained tts checkpoint epoch is: $pretrained_epoch"
        fi
    
        # Recommend the checkpoint option with the highest epoch
        if [[ $highest_saved_epoch -gt $pretrained_epoch ]]; then
            checkpoint_recommendation="saved"
        else
            checkpoint_recommendation="pretrained"
        fi
    else
        # If an override checkpoint was set, ignore all other options and use it.
        checkpoint_recommendation="override"
    fi
}

start_tmux_layout(){
# Set up tmux windows that will be used to display all of the concurrent processes used during training.
    
    tmux new-session -s training -d # start tmux session named "training" in detached mode
    tmux set-option -g mouse on     # turn on mouse scrolling
    tmux send-keys -t training "tmux set -g pane-border-status top" Enter   # Turn on pane labels

    tmux split-window -v -t training # split screen into two rows
    tmux send-keys -t training "tmux resize-pane -t 0.0 -U 34" Enter  # shrink the top pane 
    tmux send-keys -t training "tmux resize-pane -t 0.0 -R 42" Enter  

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

    # trainer_starting_checkpoint is an absolute path on the host. Use it to build a path that will work in the container if it exists
    #echo "Trainer starting checkpoint was:  $trainer_starting_checkpoint"
    #echo "current dir was                :  $PWD"
    
    
    if [[ -n "$trainer_starting_checkpoint" && -e "../$trainer_starting_checkpoint" ]]; then
        docker_starting_checkpoint_path=$(make_docker_path "$trainer_starting_checkpoint")
    else
        docker_starting_checkpoint_path=""
    fi
  
    
    # launch utils/piper_training.sh on the host which will manage training within the docker container 
    tmux send-keys -t "${TMUX_TRAINING_PANE:-0.0}" "utils/piper_training.sh $docker_starting_checkpoint_path" Enter

    # launch the tensorboard server via utils/run_tensorboard_server.sh.
    tmux send-keys -t "${TMUX_TENSORBOARD_PANE:-0.1}" "bash utils/run_tensorboard_server.sh $DOJO_NAME" Enter

    # clear the the voice exporter pane and display ready message. 
    tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.2}" "clear && echo 'Ready to export voice models' && read " Enter

    # launch the checkpoint grabber (checkpoint_grabber.sh)
    tmux send-keys -t "${TMUX_GRABBER_PANE:-0.3}" "bash utils/checkpoint_grabber.sh --save_every ${AUTO_SAVE_EVERY_NTH_CHECKPOINT_FILE} ../voice_checkpoints" Enter
    
    # launch the control console (/utils/_control_console.sh)
    tmux send-keys -t "${TMUX_CONTROL_PANE:-0.5}" "bash utils/_control_console.sh" Enter
    
    # launch the voice tester
    tmux send-keys -t "${TMUX_TESTER_PANE:-0.4}" "bash voice_tester.sh" Enter
    
}


show_setup(){
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

show_tips(){
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
}

# * MAIN PROGRAM **********************************************************
clear
load_settings
load_colors
verify_dirs_exist
empty_checkpoint_folder
show_setup
show_warning

echo -e "${GREEN}"
accept_settings
echo -e "${RESET}"

# choose between override, saved, and pretrained checkpoint options
get_starting_checkpoint_recommendation  # sets global var checkpoint_recommendation

if [[ "$has_override" = true ]]; then   
    echo "Use manual override: $override_epoch"
    trainer_starting_checkpoint=$override_checkpoint_file
    read    
fi
    
# get user's choice about whether to resume training or restart it
if [[ "$checkpoint_recommendation" = "saved" ]] || [[ "$checkpoint_recommendation" = "pretrained" ]]; then  
   if [ $has_saved_checkpoints = "true" ]; then
       if [[ $TRAIN_FROM_SCRATCH_STATE == "true" ]] || [[ $TRAIN_FROM_SCRATCH_STATE == "resume" ]]; then
           # Model was trained from scratch and has training data from prior run
           ask_about_resuming_or_restarting_from_scratch
           if [[ $resume_or_restart = "resume" ]]; then
               trainer_starting_checkpoint=$highest_saved_epoch_ckpt            
               set_train_from_scratch "resume" #        
           elif [[ $resume_or_restart = "restart" ]]; then
               trainer_starting_checkpoint=""
               set_train_from_scratch "true"
           fi
       else
           # Model was trained from pretrained checkpoint and has training data from prior run.
           ask_about_resuming_or_restarting
           if [[ $resume_or_restart = "resume" ]]; then
               trainer_starting_checkpoint=$highest_saved_epoch_ckpt            
                  
           elif [[ $resume_or_restart = "restart" ]]; then
               trainer_starting_checkpoint=$pretrained_tts_checkpoint
            # models trained from scratch have target_voice_dataset/.SCRATCH set to "true"
            # which will cause them to ignore any starting checkpoints provided.
            # this will cause them to restart training from 0.
           fi
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

show_tips
cd $DOJO_DIR/scripts
start_tmux_layout
start_tmux_processes

clear # clear screen so that it will be fresh when tmux exits
tmux a # join the multi-shell tmux session already in progress
exit 0 # resume run_training.sh which will show exit message
