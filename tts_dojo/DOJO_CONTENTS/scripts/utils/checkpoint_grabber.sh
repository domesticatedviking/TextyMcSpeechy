#!/bin/bash
trap "kill 0" SIGINT
#DOJO_DIR=$(cat .DOJO_DIR)
#BIN_DIR=$(cat .BIN_DIR)
#PIPER_PATH=$(cat .PIPER_PATH)

# infer variables from folder names
DOJO_NAME=$(awk -F'/' '{print $(NF-1)}' <<< "$PWD")
VOICE_NAME=$(awk -F'/' '{print $(NF-1)}' <<< "$PWD" | sed 's/_dojo$//')



#echo "checkpoint_grabber: VOICE_NAME is: $VOICE_NAME"
#echo "checkpoint_grabber: DOJO_NAME is: $DOJO_NAME"
#read
TTS_VOICES="tts_voices"
#communicates arrival of new file between inotify and main process.
NEW_CHECKPOINT_SIGNAL_FILE="/tmp/newcheckpoint.txt"
echo "" >$NEW_CHECKPOINT_SIGNAL_FILE
last_file_processed=""


settings_file="SETTINGS.txt"
#settings_file=$DOJO_DIR/scripts/SETTINGS.txt
if [ -e $settings_file ]; then
    source $settings_file
else
    echo "$0 - settings not found"
    echo "     expected location: $settings_file"
    echo 
    echo "press <enter> to exit"
    exit 1
fi

clear

PIPER_STEP=$PIPER_SAVE_CHECKPOINT_EVERY_N_EPOCHS
MIN_GB=${SETTINGS_GRABBER_MINIMUM_DRIVE_SPACE_GB:-20}
MIN_GB_WARNING=${DRIVE_SPACE_WARNING_THRESHOLD_GB:-10}
MINIMUM_DRIVE_SPACE=$((MIN_GB * 1024 * 1024))  # 20 GB in KB
DRIVE_SPACE_WARNING_THRESHOLD=$((MIN_GB_WARNING * 1024 * 1024))  # 10 GB in KB
last_checkpoint_file=""
last_checkpoint_size=0
last_export_duration_seconds=0
auto_save_status=$START_WITH_AUTO_SAVE  #SETTINGS.txt
auto_save_rate=$AUTO_SAVE_EVERY_NTH_CHECKPOINT_FILE
checkpoints_until_save=$auto_save_rate


check_rates(){
  echo "check whether system is flooded"

}

export_model(){
    local filepath="$1"  
    local filename="$2"  
    local epoch="$3"     
    local last_ckpt="$4" #last_ckpt 
    local voice_epoch=${VOICE_NAME}_${epoch}
    local voice_folder=$voice_epoch
    echo
    

    #echo $(date +%s) >$EXPORT_START_TIME
    echo "Exporting $voice_epoch..."
    # Define the directory path
    #directory_path="$DOJO_DIR/$TTS_VOICES/$voice_folder"
    directory_path="../$TTS_VOICES/$voice_folder"
    
    #echo "last_ckpt = $last_ckpt"
    #echo "TTS_VOICES = $TTS_VOICES"
    #echo "voice_folder = $voice_folder"
    #read
    
    # Check if the directory exists
    if [ ! -d "$directory_path" ]; then
        # If the directory does not exist, create it
        mkdir -p "$directory_path"
    fi

    tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.3}" Enter # exits the screen blanker 

    #tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.3}" "bash $DOJO_DIR/scripts/utils/_tmux_piper_export.sh $last_ckpt $DOJO_DIR/$TTS_VOICES/$voice_folder/$voice_epoch.onnx \
    #                                               } time main"  Enter

    #last_ckpt format is /home/erik/code/newtexty/TextyMcSpeechy/tts_dojo/test2_dojo/voice_checkpoints/epoch=2579-step=577032.ckpt
    #needed format is ../voice_checkpoints/epoch=2579-step=577032.ckpt
    
    export_checkpoint=$(echo "${last_ckpt}" | sed 's|.*/\(voice_checkpoints/.*\)|../\1|')

    #echo "Export_checkpoint = $export_checkpoint"
    #read

    tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.3}" "bash utils/_tmux_piper_export.sh $export_checkpoint ../tts_voices/$voice_folder/$voice_epoch.onnx ${DOJO_NAME}"  Enter

    # Put exporter pane back into its neutral state                                                
    

    # Load the duration of the export
    
    
    # To read it back in checkpoint-grabber:

    last_export_duration_seconds=$(cat $EXPORTER_LAST_EXPORT_SECONDS_FILE)
    echo "Got duration of last piper export: $last_export_duration_seconds"

    
    update_status_line
    
    tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.3}" "clear && echo 'Waiting for next model to export.' && read " Enter 

    
    
    
    
#clear

}

check_inotifywait() {
    if ! command -v inotifywait &> /dev/null; then
        echo "inotifywait is not installed on your system."
        if [ -f /etc/debian_version ]; then
            echo "You can install inotifywait using the following command:"
            echo "sudo apt-get install inotify-tools"
        elif [ -f /etc/redhat-release ]; then
            echo "You can install inotifywait using the following command:"
            echo "sudo yum install inotify-tools"
        elif [ -f /etc/fedora-release ]; then
            echo "You can install inotifywait using the following command:"
            echo "sudo dnf install inotify-tools"
        elif [ -f /etc/arch-release ]; then
            echo "You can install inotifywait using the following command:"
            echo "sudo pacman -S inotify-tools"
        elif [ "$(uname)" == "Darwin" ]; then
            echo "You can install inotifywait using Homebrew. If you don't have Homebrew installed, you can install it from https://brew.sh/"
            echo "Once Homebrew is installed, you can install inotifywait using the following command:"
            echo "brew install inotify-tools"
        else
            echo "Please install inotifywait manually or using your package manager."
        fi
        echo "Press Enter to exit"
        read
        exit 1
    else
        return 0
    fi
}

check_inotifywait

version_number=0
auto_save_rate=${AUTO_SAVE_EVERY_NTH_CHECKPOINT_FILE:-10}

while [[ "$1" == --* ]]; do
    case "$1" in
        --version_number)
            shift
            version_number=$1
            ;;
        --save_every)
            shift
            auto_save_rate=$1
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [--version_number <version_number>] [--save_every <n>] save_dir"
    exit 1
fi

save_dir=$1
#checkpoints_dir="$DOJO_DIR/training_folder/lightning_logs/version_${version_number}/checkpoints"
checkpoints_dir="../training_folder/lightning_logs/version_${version_number}/checkpoints"

first_epoch=-1
last_epoch_seen=-1
last_checkpoint_file=""
last_checkpoint_size=""
start_time=$(date +%s)
checkpoints_seen=0
checkpoints_copied=0
start_time_human=$(date +"%I:%M %p" -d @$start_time)

calculate_avg_time_per_checkpoint() {
    if [ $checkpoints_seen -gt 1 ]; then
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        avg_time_per_checkpoint=$((PIPER_STEP * elapsed_time / (checkpoints_seen - 1) ))
        avg_time_per_checkpoint_min=$(printf "%02d" $((avg_time_per_checkpoint / 60)))
        avg_time_per_checkpoint_sec=$(printf "%02d" $((avg_time_per_checkpoint % 60)))
    else
        avg_time_per_checkpoint_min="00"
        avg_time_per_checkpoint_sec="00"
    fi
}

calculate_estimated_time_until_next_saved_checkpoint() {
    if [ $last_epoch_seen -ge $first_epoch ]; then
        #next_epoch_to_save=$((first_epoch + ((last_epoch_seen - first_epoch) / auto_save_rate + 1) * auto_save_rate))
        
        if [ $checkpoints_seen -gt 1 ]; then
            estimated_time=$((checkpoints_until_save * avg_time_per_checkpoint))
            estimated_time_hours=$(printf "%02d" $((estimated_time / 3600)))
            estimated_time_minutes=$(printf "%02d" $(((estimated_time % 3600) / 60)))
            estimated_time_seconds=$(printf "%02d" $((estimated_time % 60)))
        else
            estimated_time_hours="00"
            estimated_time_minutes="00"
            estimated_time_seconds="00"
        fi
    else
        next_epoch_to_save="N/A"
        estimated_time_hours="N/A"
        estimated_time_minutes="N/A"
        estimated_time_seconds="N/A"
    fi
}

update_status_line() {
    calculate_avg_time_per_checkpoint
    calculate_estimated_time_until_next_saved_checkpoint

    available_space_kb=$(df --output=avail -k "$checkpoints_dir" | tail -1)
    available_space_gb=$(awk "BEGIN {printf \"%.2f\", $available_space_kb / (1024 * 1024)}")
    warning_message=""

    if ((available_space_kb < MINIMUM_DRIVE_SPACE)); then
        warning_message="FREE SPACE REMAINING < MINIMUM DRIVE SPACE\nNOT SAVING CHECKPOINTS"
    elif ((available_space_kb < MINIMUM_DRIVE_SPACE + DRIVE_SPACE_WARNING_THRESHOLD)); then
        warning_message="DRIVE LOW ON SPACE"
    fi

    running_time_seconds=$(( $(date +%s) - start_time ))
    running_time_hours=$(printf "%02d" $((running_time_seconds / 3600)))
    running_time_minutes=$(printf "%02d" $(((running_time_seconds % 3600) / 60)))

    tput clear
    #echo -e "Checkpoint grabber and voice maker"
    echo
    echo -e "       Available disk space : $available_space_gb GB    Stop saving below: $MIN_GB GB" 
    echo -e " Piper generates file every : $PIPER_STEP epochs"
    echo -e "      Save checkpoint every : $auto_save_rate checkpoint files"   
    echo -e "number of checkpoints saved : $checkpoints_copied"
    echo -e "      Saving checkpoints to : ${save_dir#$DOJO_DIR}"
    echo -e "           First epoch seen : $first_epoch             most recent epoch seen: $last_epoch_seen"
    echo -e "                 started at : $start_time_human                  running for : ${running_time_hours}h ${running_time_minutes}m"

    echo -e "   Avg. time per checkpoint : ${avg_time_per_checkpoint_min}m ${avg_time_per_checkpoint_sec}s"
    echo -e "      Last checkpoint saved : $(basename "$last_checkpoint_file") (${last_checkpoint_size} MB)   Last export took : $last_export_duration_seconds seconds"
    #echo   
    echo -e "       Next epoch # to save : $next_epoch_to_save"
    echo -e "       Time until next save : ${estimated_time_hours}h ${estimated_time_minutes}m ${estimated_time_seconds}s"
    echo -e "checkpoints until next save : $checkpoints_until_save"

    echo -e ""
    echo -e " Auto-save is: $auto_save_status   Auto-save: once every $auto_save_rate file(s)"
    echo -e ""
    echo -e "Commands available from this pane:"
    echo -e " [T]oggle automatic checkpoint saving on/off"
    echo -e " [S]ave current checkpoint now"
    echo -e " [I]ncrease save interval"
    echo -e " [D]ecrease save interval"
    #echo -e 
    [ -n "$warning_message" ] && echo -e "$warning_message"
    #echo
}



save_checkpoint(){
    #echo "manually saving checkpoint"
    local file_path=$newest_checkpoint
    local filename=$(basename "$file_path")
    if [[ $filename =~ epoch=([0-9]+)-step=[0-9]+\.ckpt ]]; then
        local epoch=${BASH_REMATCH[1]}
          if [ ! -f "$save_dir/$(basename "$file_path")" ]; then
               while lsof "$file_path" >/dev/null 2>&1; do
                   sleep 1
               done
               cp "$file_path" "$save_dir"
               checkpoints_copied=$((checkpoints_copied + 1))
               #echo "Copied ${file_path#$checkpoints_dir} to ${save_dir#$DOJO_DIR}"
               last_checkpoint_file=$file_path
               last_checkpoint_size=$(du -m "$file_path" | cut -f1)
               export_model "$file_path" "$filename" "$last_epoch_seen" "$save_dir/$filename"
          else
               echo "Not saving checkpoint: $filename.  File exists."
               
               #echo "File already exists in $(basename $save_dir)" 
          fi
  fi
}

increase_interval(){
   auto_save_rate=$((auto_save_rate + 1))
   checkpoints_until_save=$auto_save_rate
}


decrease_interval(){
   if [ "$auto_save_rate" -ge 2 ]; then
       auto_save_rate=$((auto_save_rate - 1))
       checkpoints_until_save=$auto_save_rate
   fi
       
}

toggle_checkpoint_saving(){
   if [ "$auto_save_status" = "ON" ]; then 
       auto_save_status="OFF"
   else
       auto_save_status="ON"
   fi
}


check_for_new_checkpoint(){
    if [ -e $NEW_CHECKPOINT_SIGNAL_FILE ]; then
        newest_checkpoint=$(cat $NEW_CHECKPOINT_SIGNAL_FILE) 
        if [ -f "$newest_checkpoint" ] && [ "$newest_checkpoint" != "$last_file_processed" ];  then
             
            process_file $newest_checkpoint
            last_file_processed=$newest_checkpoint
        fi
    else
       echo "ERROR- could not find signal file in $NEW_CHECKPOINT_SIGNAL_FILE"
    fi
}


main_loop() {

    # Main loop to read keyboard input
    while true; do
        # Read a single key press with a small timeout to prevent blocking
        if read -rsn1 -t 1 key; then
            # Convert key to lowercase
            key=$(echo "$key" | tr 'A-Z' 'a-z')
            case "$key" in
                "t") toggle_checkpoint_saving ;;
                "s") save_checkpoint ;;
                "i") increase_interval ;;
                "d") decrease_interval ;;
                *) ;;  # Ignore other keys
            esac
        fi
        check_for_new_checkpoint
        update_status_line
    done
}



process_file() {
    local file_path=$1
    local filename=$(basename "$file_path")
    if [[ $filename =~ epoch=([0-9]+)-step=[0-9]+\.ckpt ]]; then
        local epoch=${BASH_REMATCH[1]}

        if [ "$first_epoch" -eq -1 ]; then
            first_epoch=$epoch
            next_epoch_to_save=$((first_epoch + auto_save_rate * PIPER_STEP)) 
            start_time=$(date +%s)
            start_time_human=$(date +"%I:%M %p" -d @$start_time)
            #echo "First epoch set to $first_epoch"
        fi

        last_epoch_seen=$epoch
        checkpoints_seen=$((checkpoints_seen + PIPER_STEP))

        while lsof "$file_path" >/dev/null 2>&1; do
            sleep 1
        done

        update_status_line

        available_space_kb=$(df --output=avail -k "$checkpoints_dir" | tail -1)
        if ((available_space_kb < MINIMUM_DRIVE_SPACE)); then
            echo -e "FREE SPACE REMAINING < MINIMUM DRIVE SPACE\nNOT SAVING CHECKPOINTS"
            return
        fi


        
        if [ "$checkpoints_until_save" -eq "0" ]; then
             checkpoints_until_save=$auto_save_rate
             next_epoch_to_save=$((last_epoch_seen + auto_save_rate * PIPER_STEP)) 
             #save_checkpoint_file
             # This section should only run if file with same name does not exist in save_dir already.
           
            if [ "$auto_save_status" = "ON" ]; then
                if [ ! -f "$save_dir/$(basename "$file_path")" ]; then
                     while lsof "$file_path" >/dev/null 2>&1; do
                         sleep 1
                     done
                     cp "$file_path" "$save_dir"
                     checkpoints_copied=$((checkpoints_copied + 1))
                     #echo "Copied ${file_path#$checkpoints_dir} to ${save_dir#$DOJO_DIR}"
                     last_checkpoint_file=$file_path
                     last_checkpoint_size=$(du -m "$file_path" | cut -f1)
                     export_model "$file_path" "$filename" "$last_epoch_seen" "$save_dir/$filename"
                else
                     echo "Not saving checkpoint: $filename.  File exists."
                fi
            fi
            

          # end of section that should run conditionally
        fi

       checkpoints_until_save=$((checkpoints_until_save - 1)) #should decrement every we see a file.        
       last_checkpoint_file=$file_path
       last_checkpoint_size=$(du -m "$file_path" | cut -f1)

    fi
}

#if [ ! -d "$checkpoints_dir" ]; then
    echo "Training is still initializing.  This often takes several minutes"
    echo "    This window monitors ${checkpoints_dir#$DOJO_DIR}"
    echo "    for new checkpoint (.ckpt) files. "
    echo 
    echo "    Currently waiting for checkpoints directory to be created."

#fi

while [ ! -d "$checkpoints_dir" ]; do
    sleep 5
done
clear
echo "The checkpoints directory has been created."
echo "Currently watching for a checkpoint file."
echo "Training stats will appear after seeing 2 checkpoints"
echo

inotify_function(){
trap "exit" INT TERM
trap "kill 0" EXIT
inotifywait -m -e create --format "%w%f" "$checkpoints_dir"  | while read new_file; do
    echo "$checkpoints_dir got new file! $new_file"
    echo "$new_file" > $NEW_CHECKPOINT_SIGNAL_FILE
done
}

# Start inotify function in the background
inotify_function >"/tmp/INOTIFY.txt" &

main_loop





