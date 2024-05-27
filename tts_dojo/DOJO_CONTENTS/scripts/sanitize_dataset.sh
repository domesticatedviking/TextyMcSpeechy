#!/bin/bash 

# Find file pointing to base dir of this dojo

if [ -e ".DOJO_DIR" ]; then   # running from voicename_dojo
    DOJO_DIR=$(cat ".DOJO_DIR")
elif [ -e "../.DOJO_DIR" ]; then
    DOJO_DIR=$(cat "../.DOJO_DIR") # running from /scripts
else
    echo ".DOJO_DIR not found.   Exiting"
    exit 1
fi

# SETTINGS FILE
SETTINGS_MAKE_DEFAULT="$DOJO_DIR/../DOJO_CONTENTS/scripts/SETTINGS.txt"  # default settings location 
SETTINGS="$DOJO_DIR/scripts/SETTINGS.txt"


# These actions are only used if values not found in settings file.
DEFAULT_ACTION_UNKNOWN_FORMAT="MOVE_TO_SUBFOLDER"    
DEFAULT_ACTION_WRONG_FORMAT="BACKUP_FIX_AND_REPLACE"       
DEFAULT_ACTION_WRONG_RATE="BACKUP_FIX_AND_REPLACE"         
DEFAULT_ACTION_REQUIRES_CONFIRMATION="YES"


# Function to load settings from SETTINGS.txt, getting defaults if needed.
load_settings() {
    # Check if settings file exists
    if [ -f "$SETTINGS" ]; then
        # Load variables from the file
        source $SETTINGS
        action_unknown_format=$SETTINGS_DEFAULT_ACTION_UNKNOWN_FORMAT
        action_wrong_format=$SETTINGS_DEFAULT_ACTION_WRONG_FORMAT
        action_wrong_rate=$SETTINGS_DEFAULT_ACTION_WRONG_RATE
        action_requires_confirmation=$SETTINGS_DEFAULT_ACTION_REQUIRES_CONFIRMATION
        
    else
        echo "settings file not found.  Loading default values"
        # Set default values if file is not present
        action_unknown_format=$DEFAULT_ACTION_UNKNOWN_FORMAT
        action_wrong_format=$DEFAULT_ACTION_WRONG_FORMAT
        action_wrong_rate=$DEFAULT_ACTION_WRONG_RATE
        action_requires_confirmation=$DEFAULT_ACTION_REQUIRES_CONFIRMATION
    fi
}

load_settings


#echo "DOJO_DIR = '$DOJO_DIR'"
cd $DOJO_DIR/scripts/
source .colors
# CONSTANTS


# SUPPORTED_AUDIO_FORMATS
SUPPORTED_AUDIO=("wav" "flac" "mp3")
AUDIO_FILE_EXTENSIONS=("wav" "WAV" "flac" "FLAC" "mp3" "MP3") #scan for these files

# PREFERENCE CONSTANTS
MINIMUM_SAMPLES_WARN=20 
MINIMUM_SAMPLES_HARD=1 

# BASE PATHS FOR SCRIPTS
DOJO_BASENAME=$(basename "$DOJO_DIR")
WAV_DIR="$DOJO_DIR/target_voice_dataset/wav"


# PATH FOR GENERATED REPAIR SCRIPTS
REPAIR_SCRIPT="$DOJO_DIR/target_voice_dataset/autorepair.sh"
SAMPLING_RATE_SCRIPT="$DOJO_DIR/target_voice_dataset/fix_sampling_rate.sh"


# PATHS TO FILES USED TO STORE VARIABLES FOR OTHER SCRIPTS
VARFILE_PASSED="$WAV_DIR/.PASSED"
VARFILE_MAX_WORKERS="${DOJO_DIR}/scripts/.MAX_WORKERS"
VARFILE_SAMPLING_RATE="${DOJO_DIR}/scripts/.SAMPLING_RATE"

# DATASET_CLEANING_DIRECTORIES
PROBLEM_FILES_DIR="PROBLEM_FILES"
UNKNOWN_FORMAT_DIR="$PROBLEM_FILES_DIR/UNKNOWN_FORMAT"
NOT_WAV_DIR="$PROBLEM_FILES_DIR/NOT_WAV"
NOT_WAV_ORIGINAL_DIR="$NOT_WAV_DIR/ORIGINAL"
NOT_WAV_FIXED_DIR="$NOT_WAV_DIR/FIXED"

# PATHS FOR MOVING BAD AUDIO FILES
UNKNOWN_FORMAT_DIR_NAME="UNKNOWN_FORMAT"
UNKNOWN_FORMAT_PATH=${PROBLEM_FILES_DIR}/${UNKNOWN_FORMAT_DIR_NAME}
MISLABELED_AUDIO_DIR_NAME="MISLABELED"
MISLABELED_AUDIO_PATH=${PROBLEM_FILES_DIR}/${MISLABELED_AUDIO_DIR_NAME}
MISLABELED_ORIGINAL_DIR="$MISLABELED_AUDIO_PATH/ORIGINAL"
MISLABELED_FIXED_DIR="$MISLABELED_AUDIO_PATH/FIXED"

WRONG_RATE_DIR="${PROBLEM_FILES_DIR}/WRONG_SAMPLING_RATE"
WRONG_RATE_ORIGINAL_DIR="$WRONG_RATE_DIR/ORIGINAL"
WRONG_RATE_FIXED_DIR="$WRONG_RATE_DIR/FIXED"



# FILE BEHAVIOUR STRINGS
NO_CHANGES_LOG_ONLY="Do not manipulate the dataset or move files.  Log issues only"
FIX_SUBFOLDER_COPY="Keep original files in dataset, copy to subfolder and fix the copy. "
BACKUP_FIX_AND_REPLACE="Back up original file to subfolder, attempt to replace original with a repaired file."
FIX_AND_DELETE_ORIGINAL="Replace original file if repair is successful"
MOVE_TO_SUBFOLDER="Move to subfolder for manual inspection."




# DECLARE AND INIT GLOBAL VARIABLES

# init user options
action_unknown_format=$DEFAULT_ACTION_UNKNOWN_FORMAT 
action_wrong_format=$DEFAULT_ACTION_WRONG_FORMAT     
action_wrong_rate=$DEFAULT_ACTION_WRONG_RATE         
action_requires_confirmation=$DEFAULT_ACTION_REQUIRES_CONFIRMATION


move_bad_sampling_rate_files=0
fix_bad_sampling_rate_files=0


# global vars
most_common_sampling_rate=0  
declare -A sampling_rates_count 
not_audio_file_count=0
mislabeled_audio_file_count=0
not_wav_file_count=0
issue_count=0
dataset_sanitized="no"
all_rates_ok="no"
total_count=0



    


# SYSTEM FUNCTIONS

check_ffprobe() {
    # Check if ffprobe command exists
    if ! command -v ffprobe &> /dev/null; then
        echo "ffprobe is not installed on your system."

        # Check if user is on Debian/Ubuntu system
        if [ -f /etc/debian_version ]; then
            echo "You can install ffprobe using the following command:"
            echo "sudo apt-get install ffmpeg"
        # Check if user is on CentOS/RHEL system
        elif [ -f /etc/redhat-release ]; then
            echo "You can install ffprobe using the following command:"
            echo "sudo yum install ffmpeg"
        # Check if user is on Arch Linux system
        elif [ -f /etc/arch-release ]; then
            echo "You can install ffprobe using the following command:"
            echo "sudo pacman -S ffmpeg"
        # Check if user is on macOS system
        elif [ "$(uname)" == "Darwin" ]; then
            echo "You can install ffprobe using Homebrew. If you don't have Homebrew installed, you can install it from https://brew.sh/"
            echo "Once Homebrew is installed, you can install ffprobe using the following command:"
            echo "brew install ffmpeg"
        else
            echo "Please install ffprobe manually or using your package manager."
        fi
        echo "Press Enter to exit"
        read
        exit 1

    else
        return 0
    fi
}

check_tmux() {
    # Check if tmux command exists
    if ! command -v tmux &> /dev/null; then
        echo "tmux is not installed on your system."

        # Check if user is on Debian/Ubuntu system
        if [ -f /etc/debian_version ]; then
            echo "You can install tmux using the following command:"
            echo "sudo apt-get update"
            echo "sudo apt-get install tmux"
        # Check if user is on CentOS/RHEL system
        elif [ -f /etc/redhat-release ]; then
            echo "You can install tmux using the following command:"
            echo "sudo yum install tmux"
        # Check if user is on macOS system
        elif [ "$(uname)" == "Darwin" ]; then
            echo "You can install tmux using Homebrew. If you don't have Homebrew installed, you can install it from https://brew.sh/"
            echo "Once Homebrew is installed, you can install tmux using the following command:"
            echo "brew install tmux"
        else
            echo "Please install tmux manually or using your package manager."
        fi

        echo "Press Enter to exit"
        read
        exit 1

    else
        #echo "tmux is already installed."
        return 0
    fi
}


# Function to save variables to a text file
save_settings() {
    #ensure variables have values, assign defaults if they don't
    action_unknown_format=${action_unknown_format:-$DEFAULT_ACTION_UNKNOWN_FORMAT }
    action_wrong_format=${action_wrong_format:-$DEFAULT_ACTION_WRONG_FORMAT     }
    action_wrong_rate=${action_wrong_rate:-$DEFAULT_ACTION_WRONG_RATE}
    action_requires_confirmation=${action_requires_confirmation:-$DEFAULT_ACTION_REQUIRES_CONFIRMATION}

    # Saving variables to text file
    cat << EOF > $SETTINGS
action_unknown_format="$action_unknown_format"
action_wrong_format="$action_wrong_format"
action_wrong_rate="$action_wrong_rate"
EOF
}




# INITIALIZATION FUNCTIONS


 remove_verification_files(){
   rm $VARFILE_PASSED  >/dev/null 2>&1
   rm $VARFILE_MAX_WORKERS >/dev/null 2>&1
   rm $VARFILE_SAMPLING_RATE >/dev/null 2>&1
}


# UTILITY FUNCTIONS
 queue_move_file(){
     local move_from="$1"
     local move_to="$2"
     local SCRIPTFILE="$3"
     local movecommand=""
     echo "echo \"Moving \"${move_from}\" to \"${move_to}\"\"" >> "$SCRIPTFILE"
     movecommand="mv \"${move_from}\" \"${move_to}\""
     echo "$movecommand" >> "$SCRIPTFILE"
}

 queue_copy_file(){
     local copy_from="$1"
     local copy_to="$2"
     local SCRIPTFILE="$3"
     echo "echo \"Copying '${copy_from}' to '${copy_to}'\" " >> "$SCRIPTFILE"
     copycommand="cp \"${copy_from}\" \"${copy_to}\" "
     echo "$copycommand" >> "$SCRIPTFILE"
}

 queue_delete_file(){
     local filename="$1"
     local SCRIPTFILE="$2"
     echo "echo \"Deleting '${filename}'\" " >> "$SCRIPTFILE"
     deletecommand="rm \"${filename}\" "
     echo "$deletecommand" >> "$SCRIPTFILE"
}

queue_convert_to_wav(){
 local source_file="$1"
 local destination_dir="$2"
 local SCRIPTFILE="$3"
 local convert_audio_format=""
 local file_no_ext=""
 local no_path=""
 local converted_path=""
 no_path="${source_file##*/}"
 file_no_ext="${no_path%.*}"
 file_extension="${no_path##*.}"
 #corner case: original file did not contain WAV data but had uppercase extension.
 if [ $file_extension == "WAV" ]; then
     converted_extension="WAV"
 else
     converted_extension="wav"
 fi
 converted_path="${destination_dir}/$file_no_ext.$converted_extension"
 convert_audio_format="ffmpeg -loglevel error -i \"${source_file}\" \"$converted_path\" "  # > /dev/null 2>&1
 echo "echo Converting \"${source_file}\" to \"${converted_extension}\" in \"${converted_path}\" " >> "$SCRIPTFILE"  
 echo "$convert_audio_format" >> "$SCRIPTFILE"
 echo "echo     File converted successfully."  >> "$SCRIPTFILE"  
 echo " " >> "$SCRIPTFILE"
}


queue_message(){
 local message="$1"
 local SCRIPTFILE="$2"
 echo "$message" >> "$SCRIPTFILE"

}

queue_change_sampling_rate(){
 local source_file="$1"
 local target_sampling_rate="$2"
 local destination_file="$3"
 local SCRIPTFILE="$4"
 local change_sampling_rate=""
 change_sampling_rate="ffmpeg -loglevel error -i \"${source_file}\" -ar \"${target_sampling_rate}\" \"${destination_file}\" > /dev/null"
 echo "# Changing sampling rate of \"${source_file}\" to \"${target_sampling_rate}\" in \"${destination_file}\" " >> "$SCRIPTFILE" 
 echo $change_sampling_rate >> "$SCRIPTFILE"
}

add_sampling_rate_to_repair_script() {
  local sampling_rate=$1
 

  # Check if the file specified in REPAIR_SCRIPT exists
  if [[ ! -f "$REPAIR_SCRIPT" ]]; then
    echo "Error: File $REPAIR_SCRIPT does not exist."
    return 1
  fi

  # Update the 4th line of the script
  sed -i "4s/.*/SAMPLING_RATE=$sampling_rate/" "$REPAIR_SCRIPT"
}

disable_script() { 
  local SCRIPTFILE="$1"
  CURRENT_DATETIME=$(date +"%Y-%m-%d %H:%M:%S")
  # Check if the file specified in REPAIR_SCRIPT exists
  if [[ ! -e "$SCRIPTFILE" ]]; then
    echo "Error: File $SCRIPTFILE does not exist."
    return 1
  fi

  # Update the 8th line of the script
  sed -i "8s/.*/echo 'this script ran at $CURRENT_DATETIME and should not be run again.' /" "$SCRIPTFILE"
  sed -i "9s/.*/exit 0/" "$SCRIPTFILE"
}

init_repair_script(){
    rm $REPAIR_SCRIPT >/dev/null 2>&1
    CURRENT_DATETIME=$(date +"%Y-%m-%d %H:%M:%S")
    echo "# TextyMcSpeechy auto-repair script"  > $REPAIR_SCRIPT
    echo "#     created at $CURRENT_DATETIME" >> $REPAIR_SCRIPT
    echo " " >> $REPAIR_SCRIPT
    echo "SAMPLING_RATE=" >> $REPAIR_SCRIPT  # sampling rate is determined after initial scan, is substituted in.
    echo " " >> $REPAIR_SCRIPT
    echo "# all paths are relative to dataset directory :  ${WAV_DIR}" >> $REPAIR_SCRIPT
    echo " " >> $REPAIR_SCRIPT
    echo " " >> $REPAIR_SCRIPT # line 8 reserved for deactivation notice
    echo " " >> $REPAIR_SCRIPT # line 9 reserved for exit 0
    echo " " >> $REPAIR_SCRIPT
    echo "set -e" >> $REPAIR_SCRIPT
    echo "cd $WAV_DIR " >> $REPAIR_SCRIPT

}

init_sampling_rate_script(){
    local target_rate="$1"
    rm $SAMPLING_RATE_SCRIPT >/dev/null 2>&1
    CURRENT_DATETIME=$(date +"%Y-%m-%d %H:%M:%S")
    echo "# TextyMcSpeechy batch sampling rate changer script"  > $SAMPLING_RATE_SCRIPT
    echo "#     created at $CURRENT_DATETIME" >> $SAMPLING_RATE_SCRIPT
    echo " " >> $SAMPLING_RATE_SCRIPT
    echo "SAMPLING_RATE=${target_rate}" >> $SAMPLING_RATE_SCRIPT  # sampling rate is determined after initial scan, is substituted in.
    echo " " >> $SAMPLING_RATE_SCRIPT
    echo "# all paths are relative to dataset directory :  ${WAV_DIR}" >> $SAMPLING_RATE_SCRIPT
    echo " " >> $SAMPLING_RATE_SCRIPT
    echo " " >> $SAMPLING_RATE_SCRIPT # line 8 reserved for deactivation notice
    echo " " >> $SAMPLING_RATE_SCRIPT # line 9 reserved for exit 0
    echo " " >> $SAMPLING_RATE_SCRIPT
    echo "set -e" >> $SAMPLING_RATE_SCRIPT
    echo "cd $WAV_DIR" >> $SAMPLING_RATE_SCRIPT

}


# AUDIO FUNCTIONS
check_audio_file_type() {
    local checkfile="$1"

    format=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 -content_type "" "${checkfile}" 2>/dev/null)
        
    if [ -n "${format}" ]; then
        echo $format
    else
        echo ""
    fi
}

count_audio_files() {
    local type="$1"
    local directory="$WAV_DIR"

    if [[ -z "$directory" ]]; then
        echo "Error: WAV_DIR is not defined"
        return 1
    fi

    local count=$(find "$directory" -maxdepth 1 -type f \( -iname "*.$type" \) | wc -l)
    echo "$count"
}



 count_all_files() {
    #counts all audio files in a directory.  Does not include files in subfolders
    local directory="$WAV_DIR"
    local count=0
    
    # Iterate over each extension and count matching files
    for ext in "${AUDIO_FILE_EXTENSIONS[@]}"; do
        count=$((count + $(find "$directory" -maxdepth 1 -iname "*.$ext" | wc -l)))
    done
    
    echo $count
}



 get_sampling_rate(){
   local file="$1"
   sampling_rate=$(ffprobe -v error -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$file")
   echo $sampling_rate
 }


 log_sampling_rate_stats(){
    local file="$1"
    local sampling_rate=""
     # Use ffprobe to get the audio stream information
    sampling_rate=$(ffprobe -v error -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$file")
        
    # Check if the sampling rate already exists in the associative array
    if [[ -n "${sampling_rates_count[$sampling_rate]}" ]]; then
        # Increment the count of the sampling rate in the associative array
        ((sampling_rates_count[$sampling_rate]++))
    else
        # If the sampling rate does not exist, initialize its count to 1
        sampling_rates_count[$sampling_rate]=1
    fi 
 }

 find_most_common_sampling_rate(){
    # Find the most common sampling rate and sets it in global variable
    # most_common_sampling_rate
    local max_count=0
    for sampling_rate in "${!sampling_rates_count[@]}"; do
        count=${sampling_rates_count[$sampling_rate]}
        if ((count > max_count)); then
            max_count=$count
            most_common_sampling_rate=$sampling_rate
        fi
    done
 }
 
 ensure_repair_dirs_exist(){
 mkdir -p "$WAV_DIR/$NOT_WAV_FIXED_DIR" > /dev/null 2>&1
 mkdir -p "$WAV_DIR/$NOT_WAV_ORIGINAL_DIR" > /dev/null 2>&1
 mkdir -p "$WAV_DIR/$MISLABELED_ORIGINAL_DIR" > /dev/null 2>&1
 mkdir -p "$WAV_DIR/$MISLABELED_FIXED_DIR" > /dev/null 2>&1
 }

 ensure_wrong_rate_dirs_exist(){
 mkdir -p "$WAV_DIR/$WRONG_RATE_FIXED_DIR" > /dev/null 2>&1
 mkdir -p "$WAV_DIR/$WRONG_RATE_ORIGINAL_DIR" > /dev/null 2>&1
 }
 
 ensure_unknown_format_dirs_exist(){
 mkdir -p "$WAV_DIR/$UNKNOWN_FORMAT_DIR" > /dev/null 2>&1
 }
 
 
build_resampling_script() {
    local target_rate=$1
    local file_counter=0
    init_sampling_rate_script $target_rate
    queue_message "# ***BEGIN STEP 2: Resample files that are the wrong sampling rate***" "${SAMPLING_RATE_SCRIPT}"
    queue_message " " "${SAMPLING_RATE_SCRIPT}"
    echo -e "building script to change sampling rate of non-conforming files, please wait\n"

    for file in "$WAV_DIR"/*.wav; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local original_filename=$(basename "$file")
        local rate=$(get_sampling_rate "$file")

        if [ "$rate" != "$target_rate" ]; then
            queue_message "# $original_filename is not the correct sampling rate. target: $target_rate actual: $rate" "$SAMPLING_RATE_SCRIPT"
            (( file_counter++ ))
            process_sampling_rate_issue "$file" "$original_filename" "$target_rate"
        fi
    done

    queue_message "# *** END STEP 2 ***" "${SAMPLING_RATE_SCRIPT}"
}

process_sampling_rate_issue() {
    local file=$1
    local original_filename=$2
    local target_rate=$3

    case $action_wrong_rate in
        "FIX_SUBFOLDER_COPY")
            handle_fix_subfolder_copy_sampling_rate "$file" "$original_filename" "$target_rate"
            ;;
        "BACKUP_FIX_AND_REPLACE")
            handle_backup_fix_and_replace_sampling_rate "$file" "$original_filename" "$target_rate"
            ;;
        "FIX_AND_DELETE_ORIGINAL")
            handle_fix_and_delete_original_sampling_rate "$file" "$original_filename" "$target_rate"
            ;;
    esac
}

handle_fix_subfolder_copy_sampling_rate() {
    local file=$1
    local original_filename=$2
    local target_rate=$3

    ensure_wrong_rate_dirs_exist
    queue_message "# WRONG SAMPLING RATE - FIX_SUBFOLDER_COPY" "$SAMPLING_RATE_SCRIPT"
    queue_copy_file "$original_filename" "$WRONG_RATE_ORIGINAL_DIR/$original_filename" "$SAMPLING_RATE_SCRIPT"
    queue_change_sampling_rate "$original_filename" "$target_rate" "$WRONG_RATE_FIXED_DIR/$original_filename" "$SAMPLING_RATE_SCRIPT"
    queue_message " " "$SAMPLING_RATE_SCRIPT"
}

handle_backup_fix_and_replace_sampling_rate() {
    local file=$1
    local original_filename=$2
    local target_rate=$3

    ensure_wrong_rate_dirs_exist
    queue_message "# WRONG SAMPLING RATE - BACKUP_FIX_AND_REPLACE" "$SAMPLING_RATE_SCRIPT"
    queue_copy_file "$original_filename" "$WRONG_RATE_ORIGINAL_DIR/$original_filename" "$SAMPLING_RATE_SCRIPT"
    queue_change_sampling_rate "$original_filename" "$target_rate" "$WRONG_RATE_FIXED_DIR/$original_filename" "$SAMPLING_RATE_SCRIPT"
    queue_move_file "$WRONG_RATE_FIXED_DIR/$original_filename" "$WAV_DIR" "$SAMPLING_RATE_SCRIPT" 
    queue_message " " "$SAMPLING_RATE_SCRIPT"
}

handle_fix_and_delete_original_sampling_rate() {
    local file=$1
    local original_filename=$2
    local target_rate=$3

    ensure_wrong_rate_dirs_exist
    queue_message "# WRONG SAMPLING RATE - FIX_AND_DELETE-ORIGINAL" "$SAMPLING_RATE_SCRIPT"
    queue_copy_file "$original_filename" "$WRONG_RATE_ORIGINAL_DIR/$original_filename" "$SAMPLING_RATE_SCRIPT"
    queue_change_sampling_rate "$original_filename" "$target_rate" "$WRONG_RATE_FIXED_DIR/$original_filename" "$SAMPLING_RATE_SCRIPT"
    queue_move_file "$WRONG_RATE_FIXED_DIR/$original_filename" "$WAV_DIR" "$SAMPLING_RATE_SCRIPT"
    queue_delete_file "${WRONG_RATE_ORIGINAL_DIR}/${original_filename}" "$SAMPLING_RATE_SCRIPT"
    queue_message " " "$SAMPLING_RATE_SCRIPT"
}

 
 

verify_contents_and_determine_sampling_rate() {
    local dir="$WAV_DIR"
    local wav_count=$1
    local file_counter=0
    
    init_repair_script
    queue_message "# ***BEGIN STEP 1:  Scan for misnamed files and files not in WAV format***" "${REPAIR_SCRIPT}"
    queue_message " " "${REPAIR_SCRIPT}"

    for ext in "${AUDIO_FILE_EXTENSIONS[@]}"; do
        for file in "$dir"/*.$ext; do
            if [[ ! -f "$file" ]]; then
                continue
            fi

            let "file_counter++"
            echo -ne "    Scanning file ${file_counter} of ${total_count}                               \r"
            process_file "$file"
        done
        clear
    done

    queue_message "# ***END OF STEP 1***" "${REPAIR_SCRIPT}"
    queue_message " " "${REPAIR_SCRIPT}"
    queue_message " " "${REPAIR_SCRIPT}"
}

process_file() {
    local file=$1
    local original_filename=$(basename "$file")
    local filename_no_extension="${original_filename%.*}"
    local file_extension="${file##*.}"
    local file_extension_lowercase="${file_extension,,}"

    local actual_type=$(check_audio_file_type "${file}")

    if ! is_supported_audio "$actual_type"; then
        handle_unsupported_audio "$file" "$original_filename" "$file_extension_lowercase" "$actual_type"
    elif [ "$file_extension_lowercase" == "flac" ] || [ "$file_extension_lowercase" == "mp3" ]; then
        handle_non_wav_file "$file" "$original_filename" "$filename_no_extension" "$file_extension_lowercase" "$actual_type"
    elif [[ "$actual_type" != "$file_extension_lowercase" ]]; then
        handle_mislabeled_audio "$file" "$original_filename" "$filename_no_extension" "$file_extension_lowercase" "$actual_type"
    fi

    log_sampling_rate_stats "$file"
}

is_supported_audio() {
    local actual_type=$1
    [[ " ${SUPPORTED_AUDIO[@]} " =~ " $actual_type " ]]
}

handle_unsupported_audio() {
    local file=$1
    local original_filename=$2
    local file_extension_lowercase=$3
    local actual_type=$4

    (( issue_count++ ))
    echo -e "   ${YELLOW}FILE NOT RECOGNIZED AS A SUPPORTED AUDIO FILE"
    echo -e "                      Filename:  ${WHITE}$original_filename${YELLOW}"
    echo -e "            File extension was:  ${CYAN}$file_extension_lowercase${YELLOW}"
    echo -e "   File contents identified as:  ${RED}$actual_type${RESET}"
    echo -e "               selected action:  ${YELLOW}${action_unknown_format}${RESET}"

    queue_message "# $original_filename is not a supported audio file: extension was $file_extension_lowercase but contains $actual_type data." "${REPAIR_SCRIPT}"
    ((not_audio_file_count++))

    if [ $action_unknown_format = "MOVE_TO_SUBFOLDER" ]; then
        ensure_unknown_format_dirs_exist
        queue_message "# UNSUPPORTED FORMAT - MOVE_TO_SUBFOLDER" "${REPAIR_SCRIPT}"
        queue_move_file "$file" ${UNKNOWN_FORMAT_DIR} "${REPAIR_SCRIPT}"
        queue_message "echo " "${REPAIR_SCRIPT}"
        queue_message " " "${REPAIR_SCRIPT}"
    fi
}

handle_mislabeled_audio() {
    local file=$1
    local original_filename=$2
    local filename_no_extension=$3
    local file_extension_lowercase=$4
    local actual_type=$5

    (( issue_count++ ))
    echo -e "   ${RED}FOUND A MISLABELED AUDIO FILE.  EXTENSION DOES NOT MATCH CONTENTS OF FILE"
    echo -e "                      Filename:  ${WHITE}$original_filename${RED}"
    echo -e "            File extension was:  ${YELLOW}$file_extension_lowercase${RED}"
    echo -e "   File contents identified as:  ${GREEN}$actual_type${RESET}"
    echo -e "               selected action:  ${YELLOW}${action_wrong_format}${RESET}"

    queue_message "# $original_filename claimed to be a $file_extension_lowercase but contains $actual_type data." "${REPAIR_SCRIPT}"
    ((mislabeled_audio_file_count++))

    case $action_wrong_format in
        FIX_SUBFOLDER_COPY)
            handle_fix_subfolder_copy "$file" "$original_filename" "$filename_no_extension"  "$MISLABELED_ORIGINAL_DIR"  "$MISLABELED_FIXED_DIR"
            ;;
        BACKUP_FIX_AND_REPLACE)
            handle_backup_fix_and_replace "$file" "$original_filename" "$filename_no_extension" "$MISLABELED_ORIGINAL_DIR"  "$MISLABELED_FIXED_DIR"
            ;;
        FIX_AND_DELETE_ORIGINAL)
            handle_fix_and_delete_original "$file" "$original_filename" "$filename_no_extension" "$MISLABELED_ORIGINAL_DIR"  "$MISLABELED_FIXED_DIR"
            ;;
    esac
}




handle_non_wav_file() {
    local file=$1
    local original_filename=$2
    local filename_no_extension=$3
    local file_extension_lowercase=$4
    local actual_type=$5

    (( issue_count++ ))
    #echo -e "   ${YELLOW}Audio file found which was not a .wav file.${RESET}"
    #echo -e "                      Filename:  ${WHITE}$original_filename${RED}"
    #echo -e "            File extension was:  ${YELLOW}$file_extension_lowercase${RED}"
    #echo -e "   File contents identified as:  ${GREEN}$actual_type${RESET}"
    #echo -e "               selected action:  ${YELLOW}${action_wrong_format}${RESET}"

    queue_message "# $original_filename is not a .wav file.  type is: $actual_type" "${REPAIR_SCRIPT}"
    ((not_wav_file_count++))

    case $action_wrong_format in
        FIX_SUBFOLDER_COPY)
            handle_fix_subfolder_copy "$file" "$original_filename" "$filename_no_extension" "$NOT_WAV_ORIGINAL_DIR"  "$NOT_WAV_FIXED_DIR"
            ;;
        BACKUP_FIX_AND_REPLACE)
            handle_backup_fix_and_replace "$file" "$original_filename" "$filename_no_extension" "$NOT_WAV_ORIGINAL_DIR"  "$NOT_WAV_FIXED_DIR"
            ;;
        FIX_AND_DELETE_ORIGINAL)
            handle_fix_and_delete_original "$file" "$original_filename" "$filename_no_extension" "$NOT_WAV_ORIGINAL_DIR"  "$NOT_WAV_FIXED_DIR"
            ;;
    esac
}

handle_fix_subfolder_copy() {
    local file="$1"
    local original_filename="$2"
    local filename_no_extension="$3"
    local backup_dir="$4"
    local fixed_dir="$5"

    ensure_repair_dirs_exist
    echo "   File will be converted to .wav format in $NOT_WAV_FIXED_DIR"
    queue_message "# FIX_SUBFOLDER_COPY" "${REPAIR_SCRIPT}"
    queue_copy_file "$original_filename" "$backup_dir" "${REPAIR_SCRIPT}"
    queue_convert_to_wav "$backup_dir/$original_filename" "$fixed_dir" "${REPAIR_SCRIPT}"
    queue_message "echo " "${REPAIR_SCRIPT}"
    queue_message " " "${REPAIR_SCRIPT}"
}

handle_backup_fix_and_replace() {
    local file="$1"
    local original_filename="$2"
    local filename_no_extension="$3"
    local backup_dir="$4"
    local fixed_dir="$5"

    ensure_repair_dirs_exist
    #echo "File in dataset will be converted to .wav format."
    #echo "Original file will be backed up in  $backup_dir"
    #echo -e "${RED}WARNING - If your metadata.csv file contains file extensions, it will need to be manually updated${RESET}"
    queue_message "# BACKUP_FIX_AND_REPLACE" "${REPAIR_SCRIPT}"
    queue_message "# ***If your metadata.csv includes file extensions you will need to update the entry for this file***" "${REPAIR_SCRIPT}"
    queue_copy_file "$original_filename" "$backup_dir" "${REPAIR_SCRIPT}"
    queue_delete_file "$original_filename" "${REPAIR_SCRIPT}"
    queue_convert_to_wav "$backup_dir/$original_filename" "$fixed_dir" "${REPAIR_SCRIPT}"
    queue_move_file "$fixed_dir/${filename_no_extension}.wav" $WAV_DIR "${REPAIR_SCRIPT}"
    queue_message "echo " "${REPAIR_SCRIPT}"
    queue_message " " "${REPAIR_SCRIPT}"
}

handle_fix_and_delete_original() {
    local file="$1"
    local original_filename="$2"
    local filename_no_extension="$3"
    local backup_dir="$4"
    local fixed_dir="$5"
    
    ensure_repair_dirs_exist
    queue_message "# FIX_AND_DELETE_ORIGINAL" "${REPAIR_SCRIPT}"
    queue_copy_file "$original_filename" "$backup_dir" "${REPAIR_SCRIPT}"
    queue_delete_file "$original_filename" "${REPAIR_SCRIPT}"
    queue_convert_to_wav "$original_filename" "$fixed_dir" "${REPAIR_SCRIPT}"
    queue_move_file "$fixed_dir/${filename_no_extension}.wav" "$WAV_DIR" "${REPAIR_SCRIPT}"
    queue_delete_file "${backup_dir}/${original_filename}" "${REPAIR_SCRIPT}"
    queue_message "echo " "${REPAIR_SCRIPT}"
    queue_message " " "${REPAIR_SCRIPT}"
}


 get_max_workers() {
    local wav_count=$1
    local core_count=$2
    if [ "$wav_count" -ge $((2 * $core_count)) ]; then
        max_workers=$core_count
        printf "%d" "$max_workers"
    else
        max_workers=$((wav_count / 4))
        printf "%d" "$max_workers"
    fi
}


 check_varfiles() {
    if [ -e "$VARFILE_PASSED" ] && [ -e "$VARFILE_MAX_WORKERS" ] && [ -e "$VARFILE_SAMPLING_RATE" ]; then
        echo "OK"
    else
        echo "FAIL"
    fi
}



 report_audio_file_count(){
   
    total_count=0
    echo
    for audio_type in "${SUPPORTED_AUDIO[@]}"; do
        count=$(count_audio_files "$audio_type")
        total_count=$((total_count + count))
        if [ $count -gt "0" ]; then
            echo -e "    ${GREEN}${count}${YELLOW} .${audio_type} files were found in 'target_voice_dataset/wav'${RESET}"
        fi
    done
    echo -ne "\nPress ${GREEN}<ENTER>${RESET} to continue "
    read
    #echo -e "    ${GREEN}$wav_count${YELLOW} .wav files were found in 'target_voice_dataset/wav${RESET}'"
    
    echo
    
    if (($total_count < $MINIMUM_SAMPLES_HARD)); then
        echo "        ERROR: No audio files found in $DOJO_DIR/target_voice_dataset/wav"
        echo "               Did you remember to run 'add_my_files.sh' ? "
        echo
        echo "        Exiting."
        exit 1
    fi
    
    if (($total_count < $MINIMUM_SAMPLES_WARN)); then
        echo
        echo -e "         ${PURPLE}NOTICE: Small dataset detected. ${CYAN}(<$MINIMUM_SAMPLES_WARN files)${RESET}"
        echo 
        echo -e "         ${YELLOW}Smaller datasets create checkpoint files much faster than large ones."
        echo -e "         This can cause problems if you try to save every checkpoint."
        echo -e "         if you find the system can't keep up, you may need to change the following parameters"
        echo -e "         (in SETTINGS.txt):${RESET}"
        echo
        echo -e "         ${CYAN}PIPER_SAVE_CHECKPOINT_EVERY_N_EPOCHS${RESET}"  
        echo -e "               ${YELLOW}determines how often piper saves a checkpoint file"
        echo -e "               setting this number higher can improve training speed by reducing I/O,"
        echo -e "               this can also reduce wear on your hard drive"${RESET}
        echo 
        echo -e "         ${CYAN}SETTINGS_GRABBER_SAVE_EVERY_N_CHECKPOINTS"${RESET}
        echo -e "               ${YELLOW}determines how often the checkpoint grabber will make a copy of the latest checkpoint file"
        echo -e "               saved checkpoints are automatically exported as ONNX voice models."
        echo -e "               If this value is set too low with a small dataset, it can cause a race condition."
        echo -e "               The settings grabber may automatically adjust this setting if it senses that it is getting"
        echo -e "               checkpoints faster than it can process them."${RESET}

        echo
        echo -e "         ${GREEN}do you wish to: [p]roceed with courage${RESET}" 
        echo -ne "                         ${GREEN}[q]uit${RESET}  "
        read rerun

        if [ "$rerun" = "P" ] || [ "$rerun" = "p" ] || [ "$rerun" = "" ]; then
        echo -e "         \n"

        else
            echo 
            echo -e "\n    Exiting"
            exit 1
        fi
    fi
    
    #all_count=$(count_all_files)
    core_count=$(nproc)

}


 write_varfile_max_workers(){
    #calculate and write max_workers
    max_workers=$(get_max_workers "$wav_count" "$core_count")
    echo ${max_workers} > ${VARFILE_MAX_WORKERS}
 
 }

 write_varfile_sampling_rate(){
    local sampling_rate="$1"
    echo ${sampling_rate} > ${VARFILE_SAMPLING_RATE}
 
 }
 
 write_varfile_passed(){
    touch $VARFILE_PASSED
}
 
 write_varfiles(){
     local sampling_rate="$1"
  write_varfile_sampling_rate $sampling_rate
  write_varfile_max_workers   #set value in hidden file for preprocessing
  write_varfile_passed
 }
 
  
 clean_and_initialize(){
    remove_verification_files
    wav_count=$(count_audio_files "wav")
    
}



#BEGIN MAIN PROGRAM

check_ffprobe  #verify that ffprobe is installed
check_tmux

# if all varfiles are present, dataset has previously been verified..  
dataset_passed=$(check_varfiles)


if [ $dataset_passed = "OK" ]; then
    echo -e  "\n  TextyMcSpeechy dataset sanitization script" 
    echo -e  "\n  This datset has previously been verified successfully."
    echo -e  "\n      do you wish to: [s]kip verification" 
    echo -ne   "                      [r]un verification again? "
    read rerun
    
    if [ "$rerun" != "r" ] && [ "$rerun" != "R" ]; then
        echo "            Skipping dataset verification."
        exit 0
    fi
else #Means at least one varfile was missing
        echo "Now checking your dataset."
fi
# clean up any old files and ensure directories exist
clean_and_initialize
report_audio_file_count

        echo "    Verifying file contents and determining sampling rate of dataset, please wait..."

verify_contents_and_determine_sampling_rate $total_count
find_most_common_sampling_rate


rates_in_dataset="${#sampling_rates_count[@]}" # number of keys in array, should be 1.

     echo -e "            \n\n\n\nScan complete.\n\n"

if [ "$not_audio_file_count" -gt "0" ]; then
    echo -e "\n    ${RED}${not_audio_file_count}${RESET} file(s) in dataset were not identified as audio."
fi    
if [ "$mislabeled_audio_file_count" -gt "0" ]; then

    echo -e "\n    ${RED}${mislabeled_audio_file_count}${RESET}  mislabeled file(s) found."
fi
if [ "$not_wav_file_count" -gt "0" ]; then

    echo -e "\n    ${RED}${not_wav_file_count}${RESET}  non .wav file(s) found."
fi

if [ "$issue_count" -eq 0 ]; then
    echo -e "        File contents were all verified succesfully.  No repairs needed."
else
    echo -e "        Scan detected ${issue_count} issue(s) with your dataset."
    echo -e "         a repair script has been created in $REPAIR_SCRIPT"
    echo -e "        \nWould you like to: "
    echo -e "            [R]un repair script"
    echo -e "            [V]iew repair script before deciding whether to run it"
    echo -e "            [Q]uit"
    echo -ne "             "
    read repairchoice
        if [[ "$repairchoice" = "q" ]] || [[ "$repairchoice" = "Q" ]]; then
            echo "Exiting"
            exit 1
        elif [[ "$repairchoice" = "v" ]] || [[ "$repairchoice" = "V" ]];  then
            clear
            cat "$REPAIR_SCRIPT"
            echo -ne "would you like to [R]un the repair script or [Q]uit?"
            read lastchance
            if [[ "$lastchance" != "r" ]] && [[ "$lastchance" = "R" ]]; then
                echo "Exiting"
                exit 1
            else
                echo "Running repair script"
            fi
        elif [[ "$repairchoice" = "r" ]] || [[ "$repairchoice" = "R" ]]; then
            echo "Running repair script"

        fi
    bash $REPAIR_SCRIPT
    echo "press enter to continue"
    read
    disable_script $REPAIR_SCRIPT        
fi

echo -e "\n        ${CYAN}${rates_in_dataset}${RESET} sampling rate(s) found in dataset:\n"

for key in "${!sampling_rates_count[@]}"; do
    printf "        ${YELLOW}Sampling rate:  ${CYAN}%6s  Hz${YELLOW}: ${CYAN}%5s${YELLOW} files / ${CYAN}%5s${RESET} ${YELLOW}total wav files${RESET}.\n" "$key" "${sampling_rates_count[$key]}" "${wav_count}"
done

# Multiple rates were found
if [ $rates_in_dataset -gt "1" ]; then
    echo -e "         \nWARNING: multiple sampling rates found in dataset."
    echo -e "         The most common sampling rate was: ${most_common_sampling_rate}"
    echo -e "         It was found in ${sampling_rates_count[$most_common_sampling_rate]} out of ${wav_count} files.\n"
fi


# One rate was found.
if [ $rates_in_dataset = 1 ]; then
    one_sampling_rate="${!sampling_rates_count[@]}"
    echo -e "${GREEN}\n        All files in dataset were the same sampling rate:  ${CYAN}${one_sampling_rate}.${RESET}\n"
    # ensure rate is compatible with piper
    if [ $one_sampling_rate -eq 16000 ] || [ $one_sampling_rate -eq 22050 ]; then
       echo -e "        ${YELLOW}Sampling rate automatically set to ${PURPLE}$one_sampling_rate${YELLOW} Hz.${RESET}"
        all_rates_ok="yes"
        final_sampling_rate=$one_sampling_rate  
        if [ $issue_count -eq 0 ]; then
            dataset_sanitized="yes"          
        fi
    fi
fi


if [ $most_common_sampling_rate -ne 22050 ] && [ $most_common_sampling_rate -ne 16000 ]; then
    echo -e "   \n\nPiper only supports the following sampling rates:"
    echo -e "\n      1. 16000Hz for low quality models - (suitable for raspberry pi)" 
    echo -e "      2. 22050Hz for medium and high quality models - (suitable for faster computers)"
    echo -e "   \nWhat would you like to do?"
    echo -e "\n\n     [1] auto-convert your files to 16000hz"
    echo -e "     [2] auto-convert your files to 22050hz"
    echo -e "     [Q] quit."
    echo -e "  "
    read convertchoice

    
    if [ "$convertchoice" = "q" ] || [ "$convertchoice" = "Q" ]; then
        echo "\nExiting without changing your files"
        exit 1
    elif [ $convertchoice -eq 1 ]; then
        final_sampling_rate=16000
    elif [ $convertchoice -eq 2 ]; then
        final_sampling_rate=22050
    else
        echo "Invalid choice.  Exiting"
        exit 1
    fi
else
    #most common sampling rate is either 22050 or 16000
    final_sampling_rate=$most_common_sampling_rate
fi

add_sampling_rate_to_repair_script $final_sampling_rate



# all files have same sampling rate
if [ $all_rates_ok = "yes" ]; then
    write_varfiles "$final_sampling_rate"
    echo -e "        ${YELLOW}Dataset fully sanitized.  Press ${WHITE}<ENTER>${YELLOW} to continue with training${RESET}" 
    read
    exit 0
            
#files need sampling rate changed.
else
    echo "    Building script to convert non-conforming files in your dataset to ${final_sampling_rate}Hz"
    echo "    press enter to continue"
    read
    build_resampling_script ${final_sampling_rate}
fi

    echo -e "    ${file_counter} non-conforming files in your dataset will be resampled."
    echo -e "      a script to fix these files has been created in "$SAMPLING_RATE_SCRIPT""
    echo -e "    \nWould you like to: "
    echo -e "        [R]un resampling script"
    echo -e "        [V]iew resampling script before deciding whether to run it"
    echo -e "        [Q]uit"
    echo -ne "     "
    read repairchoice
        if [[ "$repairchoice" = "q" ]] || [[ "$repairchoice" = "Q" ]]; then
            echo "    Exiting.  Press enter"
            read
            exit 1
        elif [[ "$repairchoice" = "v" ]] || [[ "$repairchoice" = "V" ]];  then
            clear
            cat "$SAMPLING_RATE_SCRIPT"
            echo -ne "    would you like to [R]un the  script or [Q]uit?"
            read lastchance
            if [[ "$lastchance" != "r" ]] && [[ "$lastchance" = "R" ]]; then
                echo "    Exiting.  Press enter"
                read
                exit 1
            else
                echo "    Running resampling script"
            fi
        elif [[ "$repairchoice" = "r" ]] || [[ "$repairchoice" = "R" ]]; then
            echo "    Running resampling script"

        fi
    bash ${SAMPLING_RATE_SCRIPT}
    sr_exit_code=$?
    
    if [ $sr_exit_code -eq "0" ]; then
        echo "        Resampling script completed successfully.  Dataset successfully sanitized."
        write_varfiles "$final_sampling_rate"
        disable_script $SAMPLING_RATE_SCRIPT         
        echo "        press <enter> to continue"
        read
    fi

echo 

#If we made it this far, the dataset was good.
  
write_varfiles "$final_sampling_rate"

