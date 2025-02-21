#!/bin/bash
# checkpoint_grabber.sh
# Functions:
#     1. Monitors a folder for new .ckpt files created by Piper during a training session:
#         <voice>_dojo/training_folder/lightning_logs/version_0/checkpoints/ directory 
#     2. Periodically saves those files to <voice>_dojo/voice_checkpoints
#     3. Whenever it saves a .ckpt it exports it as a usable piper voice in <voice>_dojo/tts_voices 
# This version now exports voices with names that comply with piper's specs.

trap "kill 0" SIGINT
echo "Starting checkpoint_grabber.sh"

# infer variables from parent directory name
DOJO_NAME=$(awk -F'/' '{print $(NF-1)}' <<< "$PWD")
VOICE_NAME=$(awk -F'/' '{print $(NF-1)}' <<< "$PWD" | sed 's/_dojo$//')
SETTINGS_FILE="SETTINGS.txt"
TTS_VOICES="tts_voices"  # constant for name of folder that will hold tts voices

# path to temporary file on host that communicates arrival of new checkpoint file between inotify and main process.
NEW_CHECKPOINT_SIGNAL_FILE="/tmp/newcheckpoint.txt"
echo "" >$NEW_CHECKPOINT_SIGNAL_FILE
last_file_processed=""


# load settings
if [ -e $SETTINGS_FILE ]; then
    source $SETTINGS_FILE
else
    echo "$0 - settings not found"
    echo "     expected location: $SETTINGS_FILE"
    echo 
    echo "press <enter> to exit"
    exit 1
fi

DATASET_CONF_FILE="../target_voice_dataset/dataset.conf"
QUALITY_FILE="../target_voice_dataset/.QUALITY"
quality=""

if [[ -f $QUALITY_FILE ]]; then
    QUALITY_CODE=$(cat $QUALITY_FILE)
else
    echo "Error: .QUALITY file not found."
    exit 1
fi

# Load dataset.conf
if [ -e $DATASET_CONF_FILE ]; then
    source $DATASET_CONF_FILE
else
    echo "$0 - dataset.conf not found"
    echo "     expected location: $DATASET_CONF_FILE"
    echo 
    exit 1
fi
# Set PIPER_FILENAME_PREFIX from dataset.conf


if [ "$QUALITY_CODE" = "L" ]; then
    quality="low"
elif [ "$QUALITY_CODE" = "M" ]; then
    quality="medium"
elif [ "$QUALITY_CODE" = "H" ]; then
    quality="high" 
else 
    echo "Error - invalid value for quality: $QUALITY_CODE"
    exit 1
fi



clear # clear the screen
# load constants from values sourced from SETTINGS, supply defaults if not specified
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


export_model(){
# manages exporting saved ckpt files as usable piper voices 
    local filepath="$1"  
    local filename="$2"  
    local epoch="$3"     
    local last_ckpt="$4" 
    local voice_epoch=${VOICE_NAME}_${epoch}
    local voice_folder=$voice_epoch
    
    voice_folder_path="../$TTS_VOICES/$voice_folder"
    
    # Ensure voice folder exists
    if [ ! -d "$voice_folder_path" ]; then
        mkdir -p "$voice_folder_path"
    fi
   
    # send an "enter" keystroke to the exporter pane to end the "read" command that is preventing a command prompt from displaying
    tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.3}" Enter  

    # convert absolute path of checkpoint file on host to relative path needed by docker container.
    # needed format is ../voice_checkpoints/epoch=2579-step=577032.ckpt
    export_checkpoint=$(echo "${last_ckpt}" | sed 's|.*/\(voice_checkpoints/.*\)|../\1|')
    
    # builds filename according to piper's requirements eg "en_US-somevoice_3439-medium.onnx" 
    piper_compliant_filename_onnx="${PIPER_FILENAME_PREFIX}-${VOICE_NAME}_${epoch}-${quality}.onnx"
    
    # send command to exporter pane which will create the .onnx file for the piper tts voice in a subfolder of <voice>_dojo/tts_voices
    tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.3}" "bash utils/_tmux_piper_export.sh $export_checkpoint ../tts_voices/$voice_folder/$piper_compliant_filename_onnx ${DOJO_NAME}"  Enter
    
    # Load the amount of time the export took from temporary file
    last_export_duration_seconds=$(cat $EXPORTER_LAST_EXPORT_SECONDS_FILE)
    echo "Got duration of last piper export: $last_export_duration_seconds"
    
    # refresh checkpoint grabber info
    update_grabber_status
    
    # Put exporter pane back into its neutral state.
    tmux send-keys -t "${TMUX_EXPORTER_PANE:-0.3}" "clear && echo 'Waiting for next model to export.' && read " Enter 
}


check_inotifywait() {
# make sure the inotifywait package is installed.
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

update_grabber_status() {
# refreshes output of checkpoint_grabber pane
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
    
    echo
    echo -e "       Available disk space : $available_space_gb GB    Stop saving below: $MIN_GB GB" 
    echo -e " Piper generates file every : $PIPER_STEP epochs"
    echo -e "      Save checkpoint every : $auto_save_rate checkpoint files"   
    echo -e "number of checkpoints saved : $checkpoints_copied"
    echo -e "      Saving checkpoints to : ${DOJO_NAME}/$(basename $save_dir)"
    echo -e "           First epoch seen : $first_epoch             most recent epoch seen: $last_epoch_seen"
    echo -e "                 started at : $start_time_human                  running for : ${running_time_hours}h ${running_time_minutes}m"

    echo -e "   Avg. time per checkpoint : ${avg_time_per_checkpoint_min}m ${avg_time_per_checkpoint_sec}s"
    echo -e "      Last checkpoint saved : $(basename "$last_checkpoint_file") (${last_checkpoint_size} MB)   Last export took : $last_export_duration_seconds seconds"   
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
    # adds warning message if there is one
    [ -n "$warning_message" ] && echo -e "$warning_message"
}

save_checkpoint(){
# copies current checkpoint file to <name>_dojo/voice_checkpoints and exports 
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
               last_checkpoint_file=$file_path
               last_checkpoint_size=$(du -m "$file_path" | cut -f1)
               export_model "$file_path" "$filename" "$last_epoch_seen" "$save_dir/$filename"
          else
               echo "Not saving checkpoint: $filename.  File exists."
          fi
  fi
}

increase_interval(){
# increases time between saving checkpoint files
   auto_save_rate=$((auto_save_rate + 1))
   checkpoints_until_save=$auto_save_rate
}


decrease_interval(){
# decreases time between saving checkpoint files
   if [ "$auto_save_rate" -ge 2 ]; then
       auto_save_rate=$((auto_save_rate - 1))
       checkpoints_until_save=$auto_save_rate
   fi
}

toggle_checkpoint_saving(){
# turns automatic saving of checkpoints on and off
   if [ "$auto_save_status" = "ON" ]; then 
       auto_save_status="OFF"
   else
       auto_save_status="ON"
   fi
}


check_for_new_checkpoint(){
# monitors a file that inotify creates to signal arrival of a new checkpoint file
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


process_file() {
# handle the arrival of a new checkpoint file
    local file_path=$1
    local filename=$(basename "$file_path")
    if [[ $filename =~ epoch=([0-9]+)-step=[0-9]+\.ckpt ]]; then
        local epoch=${BASH_REMATCH[1]}

        if [ "$first_epoch" -eq -1 ]; then
            first_epoch=$epoch
            next_epoch_to_save=$((first_epoch + auto_save_rate * PIPER_STEP)) 
            start_time=$(date +%s)
            start_time_human=$(date +"%I:%M %p" -d @$start_time)
        fi

        last_epoch_seen=$epoch
        checkpoints_seen=$((checkpoints_seen + PIPER_STEP))

        while lsof "$file_path" >/dev/null 2>&1; do
            sleep 1
        done

        update_grabber_status

        available_space_kb=$(df --output=avail -k "$checkpoints_dir" | tail -1)
        if ((available_space_kb < MINIMUM_DRIVE_SPACE)); then
            echo -e "FREE SPACE REMAINING < MINIMUM DRIVE SPACE\nNOT SAVING CHECKPOINTS"
            return
        fi
        
        if [ "$checkpoints_until_save" -eq "0" ]; then
             checkpoints_until_save=$auto_save_rate
             next_epoch_to_save=$((last_epoch_seen + auto_save_rate * PIPER_STEP)) 
             
             # This section should only run if file with same name does not exist in save_dir already.
           
             if [ "$auto_save_status" = "ON" ]; then
                 if [ ! -f "$save_dir/$(basename "$file_path")" ]; then
                     while lsof "$file_path" >/dev/null 2>&1; do
                         sleep 1
                     done
                     cp "$file_path" "$save_dir"
                     checkpoints_copied=$((checkpoints_copied + 1))
                     last_checkpoint_file=$file_path
                     last_checkpoint_size=$(du -m "$file_path" | cut -f1)
                     export_model "$file_path" "$filename" "$last_epoch_seen" "$save_dir/$filename"
                else
                     echo "Not saving checkpoint: $filename.  File exists."
                fi
            fi
        fi

        checkpoints_until_save=$((checkpoints_until_save - 1))        
        last_checkpoint_file=$file_path
        last_checkpoint_size=$(du -m "$file_path" | cut -f1)
    fi
}

show_training_dir_empty_message(){
# displays before the initial checkpoint file is created on a new run
    echo "Training is still initializing.  This often takes several minutes"
    echo
    echo "    If training is working properly, you should see "
    echo "    \"rank_zero_warn(\" in the PIPER TRAINING RAW OUTPUT pane."
    echo
    echo "    This window monitors ${checkpoints_dir#$DOJO_DIR}"
    echo "    for new checkpoint (.ckpt) files. "
    echo 
    echo "    Currently waiting for Piper to create checkpoints directory."
}

show_training_dir_created_message(){
# displays when the checkpoints directory is first created 
    clear
    echo "The checkpoints directory has been created."
    echo "Currently watching for a checkpoint file."
    echo "Training stats will appear after seeing 2 checkpoints"
    echo
}

inotify_function(){
# subprocess that monitors checkpoint directory for creation of new files
# creates a signal file to pass the new file name to the main program
    trap "exit" INT TERM
    trap "kill 0" EXIT
    inotifywait -m -e create --format "%w%f" "$checkpoints_dir"  | while read new_file; do
        echo "$checkpoints_dir got new file! $new_file"
        echo "$new_file" > $NEW_CHECKPOINT_SIGNAL_FILE
    done
}


main_loop() {
# Main loop to read keyboard input and watch for new checkpoint files
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
        update_grabber_status
    done
}


# MAIN PROGRAM START *************************************************
check_inotifywait  # make sure dependency is installed

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
checkpoints_dir="../training_folder/lightning_logs/version_${version_number}/checkpoints"

first_epoch=-1
last_epoch_seen=-1
last_checkpoint_file=""
last_checkpoint_size=""
start_time=$(date +%s)
checkpoints_seen=0
checkpoints_copied=0
start_time_human=$(date +"%I:%M %p" -d @$start_time)

show_training_dir_empty_message

# wait for piper to create checkpoints_dir
while [ ! -d "$checkpoints_dir" ]; do
    sleep 5
done

show_training_dir_created_message

# Start inotify function which will run continuously in the background
inotify_function >"/tmp/INOTIFY.txt" &

main_loop



