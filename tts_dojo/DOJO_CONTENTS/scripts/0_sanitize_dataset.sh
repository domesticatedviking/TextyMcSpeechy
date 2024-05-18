#!/bin/bash 

# 0_pretraining_checks.sh


# Checks your dataset prior to training.
# 1.  Counts the number of files in your dataset.  done
# 2.  Determines the number of cores in your computer done
# 3.  Calculates an appropriate value for max_workers in piper_train.preprocess and stores it in .MAX_WORKERS
# 4.  Checks dataset to make sure all files are the same sampling rate.
# 5.  Checks whether files are what the extension claims they are.
# 6.  Creates a list of files which don't conform.
# 7.  Infers the dataset's sampling rate and sets it in .SAMPLING_RATE
# 8.  Prompts user to ensure pretrained voice being used is appropriate for the sampling rate

# Known issues: File extensions are case sensitive.   Files without .wav extension are not picked up by the main loop


# Drop into to dojo to store its absolute path
DOJO_DIR=$(cat .DOJO_DIR)
#echo "DOJO_DIR = '$DOJO_DIR'"
cd $DOJO_DIR/scripts/

# CONSTANTS

# ANSI COLORS
RESET='\033[0m' # Reset text color to default
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD_BLACK='\033[1;30m'
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'
BOLD_PURPLE='\033[1;35m'
BOLD_CYAN='\033[1;36m'
BOLD_WHITE='\033[1;37m'

# SUPPORTED_AUDIO_FORMATS
SUPPORTED_AUDIO=("wav" "flac" "mp3")
AUDIO_FILE_EXTENSIONS=("wav" "WAV" "flac" "FLAC" "mp3" "MP3") #scan for these files

# PREFERENCE CONSTANTS
MINIMUM_SAMPLES_WARN=20 
MINIMUM_SAMPLES_HARD=1 

# BASE PATHS FOR SCRIPTS
DOJO_BASENAME=$(basename "$DOJO_DIR")
WAV_DIR="$DOJO_DIR/target_voice_dataset/wav"

# SETTINGS FILE
SETTINGS_MAKE_DEFAULT="$DOJO_DIR/../DOJO_CONTENTS/scripts/settings.txt" 
SETTINGS="$DOJO_DIR/scripts/settings.txt"

# PATH FOR GENERATED REPAIR SCRIPT
REPAIR_SCRIPT="$DOJO_DIR/target_voice_dataset/autorepair.sh"
SAMPLING_RATE_SCRIPT="$DOJO_DIR/target_voice_dataset/fix_sampling_rate.sh"

# PATHS FOR MOVING BAD AUDIO FILES
UNKNOWN_FORMAT_DIR_NAME="UNKNOWN_FORMAT"
UNKNOWN_FORMAT_PATH=${WAV_DIR}/$UNKNOWN_FORMAT_DIR_NAME}
WRONG_AUDIO_DIR_NAME="NOT_WAV"
WRONG_AUDIO_PATH=${WAV_DIR}/$WRONG_AUDIO_DIR_NAME}


# PATHS TO FILES USED TO STORE VARIABLES FOR OTHER SCRIPTS
VARFILE_PASSED="${DOJO_DIR}/wav/.PASSED"
VARFILE_MAX_WORKERS="${DOJO_DIR}/scripts/.MAX_WORKERS"
VARFILE_SAMPLING_RATE="${DOJO_DIR}/scripts/.SAMPLING_RATE"

# DATASET_CLEANING_DIRECTORIES
PROBLEM_FILES_DIR="PROBLEM_FILES"
UNKNOWN_FORMAT_DIR="$PROBLEM_FILES_DIR/UNKNOWN_FORMAT"
WRONG_FORMAT_DIR="$PROBLEM_FILES_DIR/MISLABELED"
WRONG_FORMAT_ORIGINAL_DIR="$WRONG_FORMAT_DIR/ORIGINAL"
WRONG_FORMAT_FIXED_DIR="$WRONG_FORMAT_DIR/FIXED"
#FIXED_DIR="$PROBLEM_FILES_DIR/FIXED"  ERROR?

WRONG_RATE_DIR="${PROBLEM_FILES_DIR}/WRONG_SAMPLING_RATE"
WRONG_RATE_ORIGINAL_DIR="$WRONG_RATE_DIR/ORIGINAL"
WRONG_RATE_FIXED_DIR="$WRONG_RATE_DIR/FIXED"




# FILE BEHAVIOUR STRINGS
NO_CHANGES_LOG_ONLY="Do not manipulate the dataset or move files.  Log issues only"
FIX_SUBFOLDER_COPY="Keep original files in dataset, copy to subfolder and fix the copy. "
BACKUP_FIX_AND_REPLACE="Back up original file to subfolder, attempt to replace original with a repaired file."
FIX_AND_DELETE_ORIGINAL="Replace original file if repair is successful"
MOVE_TO_SUBFOLDER="Move to subfolder for manual inspection."

DEFAULT_ACTION_UNKNOWN_FORMAT="MOVE_TO_SUBFOLDER"      #[MOVE_TO_SUBFOLDER, NO_CHANGES_LOG_ONLY]
DEFAULT_ACTION_WRONG_FORMAT="BACKUP_FIX_AND_REPLACE"       #[BACKUP_FIX_AND_REPLACE, FIX_AND_DELETE_ORIGINAL, FIX_SUBFOLDER_COPY, NO_CHANGES_LOG_ONLY]
DEFAULT_ACTION_WRONG_RATE="BACKUP_FIX_AND_REPLACE"         #[BACKUP_AND_REPLACE, REPLACE_ORIGINAL, FIX_SUBFOLDER_COPY, NO_CHANGES_LOG_ONLY]
DEFAULT_ACTION_REQUIRES_CONFIRMATION="YES" 

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
wrong_audio_file_count=0
issue_count=0
dataset_sanitized="no"
all_rates_ok="no"



    


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

# Function to load variables from the text file, setting defaults if file is not present
load_settings() {
    # Check if settings file exists
    if [ -f "$SETTINGS" ]; then
        # Load variables from the file
        source $SETTINGS
    else
        echo "settings file not found.  Loading default values"
        # Set default values if file is not present
        action_unknown_format=$DEFAULT_ACTION_UNKNOWN_FORMAT
        action_wrong_format=$DEFAULT_ACTION_WRONG_FORMAT
        action_wrong_rate=$DEFAULT_ACTION_WRONG_RATE
        action_requires_confirmation=$DEFAULT_ACTION_REQUIRES_CONFIRMATION
    fi
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
 #echo "queue_convert_to_wav"
 #echo "source_file = $source_file"
 #echo "destination_dir = $destination_dir"
 
 convert_audio_format="ffmpeg -loglevel error -i \"${source_file}\" \"$converted_path\" "  # > /dev/null 2>&1
 echo "echo Converting \"${source_file}\" to \"${converted_extension}\" in \"${converted_path}\" " >> "$SCRIPTFILE"  
 echo "$convert_audio_format" >> "$SCRIPTFILE"
 echo "echo     File converted successfully.  press enter"  >> "$SCRIPTFILE"  
 echo "read" >> "SCRIPTFILE"
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
  if [[ ! -f "$script" ]]; then
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

count_wav_files() {
    local directory="$WAV_DIR"
    local count=$(find "$directory" -maxdepth 1 -type f \( -iname "*.wav" -o -iname "*.WAV" \) | wc -l)
    echo $count 
}

 unused_count_all_files() {
    local directory=$WAV_DIR
    local count=$(find "$directory" -maxdepth 1 -iname "*.*" | wc -l)
    echo $count 
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
 
 ensure_wrong_format_dirs_exist(){
 mkdir -p "$WAV_DIR/$WRONG_FORMAT_FIXED_DIR" > /dev/null 2>&1
 mkdir -p "$WAV_DIR/$WRONG_FORMAT_ORIGINAL_DIR" > /dev/null 2>&1
 }

 ensure_wrong_rate_dirs_exist(){
 mkdir -p "$WAV_DIR/$WRONG_RATE_FIXED_DIR" > /dev/null 2>&1
 mkdir -p "$WAV_DIR/$WRONG_RATE_ORIGINAL_DIR" > /dev/null 2>&1
 }
 
 ensure_unknown_format_dirs_exist(){
 mkdir -p "$WAV_DIR/$UNKNOWN_FORMAT_DIR" > /dev/null 2>&1
 }
 
 spinner() {
     last="$1"
     if [ $last = "|" ]; then
         $last="/"
         echo last
     elif [ $last = "/" ]; then
         $last="-"
         echo last
     elif [ $last = "-" ]; then
         last = "\\"
         echo last
     elif [ $last = "\\" ]; then
         last = "|"
     fi
 
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
        FIX_SUBFOLDER_COPY)
            handle_fix_subfolder_copy_sampling_rate "$file" "$original_filename" "$target_rate"
            ;;
        BACKUP_FIX_AND_REPLACE)
            handle_backup_fix_and_replace_sampling_rate "$file" "$original_filename" "$target_rate"
            ;;
        FIX_AND_DELETE_ORIGINAL)
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
    queue_delete_file "${WRONG_RATE_ORIGINAL_DIR}${original_filename}" "$SAMPLING_RATE_SCRIPT"
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
            echo -ne "Scanning file ${file_counter} of ${wav_count}                               \r"
            process_file "$file"
        done
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
    elif [[ "$actual_type" != "$file_extension_lowercase" ]]; then
        handle_mislabeled_audio "$file" "$original_filename" "$filename_no_extension" "$file_extension_lowercase" "$actual_type"
    elif [ "$file_extension_lowercase" == "flac" ] || [ "$file_extension_lowercase" == "mp3" ]; then
        handle_non_wav_file "$file" "$original_filename" "$filename_no_extension" "$file_extension_lowercase" "$actual_type"
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
    ((wrong_audio_file_count++))

    case $action_wrong_format in
        FIX_SUBFOLDER_COPY)
            handle_fix_subfolder_copy "$file" "$original_filename" "$filename_no_extension"
            ;;
        BACKUP_FIX_AND_REPLACE)
            handle_backup_fix_and_replace "$file" "$original_filename" "$filename_no_extension"
            ;;
        FIX_AND_DELETE_ORIGINAL)
            handle_fix_and_delete_original "$file" "$original_filename" "$filename_no_extension"
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
    echo -e "   ${YELLOW}Audio file found which was not a .wav file.${RESET}"
    echo -e "                      Filename:  ${WHITE}$original_filename${RED}"
    echo -e "            File extension was:  ${YELLOW}$file_extension_lowercase${RED}"
    echo -e "   File contents identified as:  ${GREEN}$actual_type${RESET}"
    echo -e "               selected action:  ${YELLOW}${action_wrong_format}${RESET}"

    queue_message "# $original_filename is not a .wav file.  type is: $actual_type" "${REPAIR_SCRIPT}"
    ((wrong_audio_file_count++))

    case $action_wrong_format in
        FIX_SUBFOLDER_COPY)
            handle_fix_subfolder_copy "$file" "$original_filename" "$filename_no_extension"
            ;;
        BACKUP_FIX_AND_REPLACE)
            handle_backup_fix_and_replace "$file" "$original_filename" "$filename_no_extension"
            ;;
        FIX_AND_DELETE_ORIGINAL)
            handle_fix_and_delete_original "$file" "$original_filename" "$filename_no_extension"
            ;;
    esac
}

handle_fix_subfolder_copy() {
    local file=$1
    local original_filename=$2
    local filename_no_extension=$3

    ensure_wrong_format_dirs_exist
    echo "   File will be converted to .wav format in $WRONG_FORMAT_FIXED_DIR"
    queue_message "# FIX_SUBFOLDER_COPY" "${REPAIR_SCRIPT}"
    queue_copy_file "$original_filename" "$WRONG_FORMAT_ORIGINAL_DIR" "${REPAIR_SCRIPT}"
    queue_convert_to_wav "$WRONG_FORMAT_ORIGINAL_DIR/$original_filename" "$WRONG_FORMAT_FIXED_DIR" "${REPAIR_SCRIPT}"
    queue_message "echo " "${REPAIR_SCRIPT}"
    queue_message " " "${REPAIR_SCRIPT}"
}

handle_backup_fix_and_replace() {
    local file=$1
    local original_filename=$2
    local filename_no_extension=$3

    ensure_wrong_format_dirs_exist
    echo "File in dataset will be converted to .wav format."
    echo "Original file will be backed up in  $WRONG_FORMAT_ORIGINAL_DIR"
    echo -e "${RED}WARNING - If your metadata.csv file contains file paths, it will need to be manually updated${RESET}"
    queue_message "# BACKUP_FIX_AND_REPLACE" "${REPAIR_SCRIPT}"
    queue_message "# ***If your metadata.csv includes file extensions you will need to update the entry for this file***" "${REPAIR_SCRIPT}"
    queue_copy_file "$original_filename" "$WRONG_FORMAT_ORIGINAL_DIR" "${REPAIR_SCRIPT}"
    queue_convert_to_wav "$WRONG_FORMAT_ORIGINAL_DIR/$original_filename" "$WRONG_FORMAT_FIXED_DIR" "${REPAIR_SCRIPT}"
    queue_move_file "$WRONG_FORMAT_FIXED_DIR/${filename_no_extension}.wav" $WAV_DIR "${REPAIR_SCRIPT}"
    queue_message "echo " "${REPAIR_SCRIPT}"
    queue_message " " "${REPAIR_SCRIPT}"
}

handle_fix_and_delete_original() {
    local file=$1
    local original_filename=$2
    local filename_no_extension=$3

    ensure_wrong_format_dirs_exist
    queue_message "# FIX_AND_DELETE_ORIGINAL" "${REPAIR_SCRIPT}"
    queue_copy_file "$original_filename" "$WRONG_FORMAT_ORIGINAL_DIR" "${REPAIR_SCRIPT}"
    queue_convert_to_wav "$original_filename" "$WRONG_FORMAT_FIXED_DIR" "${REPAIR_SCRIPT}"
    queue_move_file "$WRONG_FORMAT_FIXED_DIR/${filename_no_extension}.wav" "$WAV_DIR" "${REPAIR_SCRIPT}"
    queue_delete_file "${WRONG_FORMAT_ORIGINAL_DIR}$original_filename" "${REPAIR_SCRIPT}"
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
        return 1
    else
        return 0
    fi
}



 report_wav_file_count(){
   
    
    echo
    echo -e "    ${GREEN}$wav_count${YELLOW} .wav files were found in 'target_voice_dataset/wav${RESET}'"
    echo
    
    if (($wav_count < $MINIMUM_SAMPLES_HARD)); then
        echo "        ERROR: No wav files found in $DOJO_DIR/target_voice_dataset/wav"
        echo "               Did you remember to run 'add_my_files.sh' ? "
        exit 1
    fi
    
    if (($wav_count < $MINIMUM_SAMPLES_WARN)); then
        echo
        echo "         NOTICE: Small dataset detected. ( <$MINIMUM_SAMPLES_WARN )"
        echo 
        echo " do you wish to: [p]roceed with courage" 
        echo -n "                 [q]uit "
        read rerun
    
        if [ $rerun = "p" ] || [ $rerun = "p" ]; then
            echo "    Adventure intensifies."

        else
            echo 
            echo "    That probably makes sense."
            echo "    Exiting"
            exit 1
        fi
    fi
    
    all_count=$(count_all_files)
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
 
 write_varfiles(){
     local sampling_rate="$1"
  write_varfile_sampling_rate $sampling_rate
  write_varfile_max_workers   #set value in hidden file for preprocessing
 }
 
  
 clean_and_initialize(){
    remove_verification_files
    wav_count=$(count_wav_files)
}



#BEGIN MAIN PROGRAM

check_ffprobe  #verify that ffprobe is installed
check_tmux

# if all varfiles are present, dataset has previously been verified..  
if check_varfiles; then
    echo -e  "\n  TextyMcSpeechy dataset sanitization script" 
    echo -e  "\n  This datset has previously been verified successfully."
    echo -e  "\n      do you wish to: [s]kip verification" 
    echo -ne   "                      [r]un verification again? "
    read rerun
    
    if [ "$rerun" != "r" ] && [ "$rerun" != "R" ]; then
        echo "Skipping dataset verification."
        exit 0
    fi
else #Means at least one varfile was missing
    echo "Beginning verification."
fi
# clean up any old files and ensure directories exist
clean_and_initialize
report_wav_file_count

echo "Verifying file contents and determining sampling rate of dataset, please wait..."

verify_contents_and_determine_sampling_rate $wav_count
find_most_common_sampling_rate


rates_in_dataset="${#sampling_rates_count[@]}" # number of keys in array, should be 1.

echo -e "\n\n\n\nScan complete."

if [ $not_audio_file_count -gt 0 ]; then
    echo -e "\n    ${RED}${not_audio_file_count}${RESET} file(s) in dataset were not identified as audio."
fi
if [ $wrong_audio_file_count -gt 0 ]; then

    echo -e "\n    ${RED}${wrong_audio_file_count}${RESET}  mislabeled file(s) found."
fi

if [ "$issue_count" -eq 0 ]; then
    echo -e "File contents were all verified succesfully.  No repairs needed."
else
    echo -e "Scan detected ${issue_count} issue(s) with your dataset."
    echo -e "  a repair script has been created in $REPAIR_SCRIPT"
    echo -e "\nWould you like to: "
    echo -e "    [R]un repair script"
    echo -e "    [V]iew repair script before deciding whether to run it"
    echo -e "    [Q]uit"
    echo -ne "     "
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
fi

echo -e "\n   ${CYAN}${rates_in_dataset}${RESET} sampling rate(s) found in dataset:\n"

for key in "${!sampling_rates_count[@]}"; do
    printf "     Sampling rate:  %6s  Hz: %5s files / %5s total wav files.\n" "$key" "${sampling_rates_count[$key]}" "${wav_count}"
done

# Multiple rates were found
if [ $rates_in_dataset -gt "1" ]; then
    echo -e "\n     WARNING: multiple sampling rates found in dataset."
    echo -e "     The most common sampling rate was: ${most_common_sampling_rate}"
    echo -e "     It was found in ${sampling_rates_count[$most_common_sampling_rate]} out of ${wav_count} files.\n"
fi


# One rate was found.
if [ $rates_in_dataset = 1 ]; then
    one_sampling_rate="${!sampling_rates_count[@]}"
    echo -e "All files in dataset were the same sampling rate:  ${one_sampling_rate}.\n"
    # ensure rate is compatible with piper
    if [ $one_sampling_rate -eq 16000 ] || [ $one_sampling_rate -eq 22050 ]; then
        echo "Sampling rate automatically set to $one_sampling_rate Hz."
        all_rates_ok="yes"
        final_sampling_rate=$one_sampling_rate  
        if [ $issue_count -eq 0 ]; then
            dataset_sanitized="yes"          
        fi
    fi
fi


if [ $most_common_sampling_rate -ne 22050 ] && [ $most_common_sampling_rate -ne 16000 ]; then
    echo -e "    \n\nPiper only supports the following sampling rates:"
    echo -e "\n     1. 16000Hz for low quality models - (suitable for raspberry pi)" 
    echo -e "     2. 22050Hz for medium and high quality models - (suitable for faster computers)"
    echo -e "\nWhat would you like to do?"
    echo -e "\n\n [1] auto-convert your files to 16000hz"
    echo -e " [2] auto-convert your files to 22050hz"
    echo -e " [Q] quit."
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
    echo "Dataset fully sanitized.  Press Enter to continue with training" 
    read
    exit 0
            
#files need sampling rate changed.
else
    echo "Building script to convert non-conforming files in your dataset to ${final_sampling_rate}Hz"
    echo "press enter to continue"
    read
    build_resampling_script ${final_sampling_rate}
fi

    echo -e "${file_counter} non-conforming files in your dataset will be resampled."
    echo -e "  a script to fix these files has been created in "$SAMPLING_RATE_SCRIPT""
    echo -e "\nWould you like to: "
    echo -e "    [R]un resampling script"
    echo -e "    [V]iew resampling script before deciding whether to run it"
    echo -e "    [Q]uit"
    echo -ne "     "
    read repairchoice
        if [[ "$repairchoice" = "q" ]] || [[ "$repairchoice" = "Q" ]]; then
            echo "Exiting.  Press enter"
            read
            exit 1
        elif [[ "$repairchoice" = "v" ]] || [[ "$repairchoice" = "V" ]];  then
            clear
            cat "$SAMPLING_RATE_SCRIPT"
            echo -ne "would you like to [R]un the  script or [Q]uit?"
            read lastchance
            if [[ "$lastchance" != "r" ]] && [[ "$lastchance" = "R" ]]; then
                echo "Exiting.  Press enter"
                read
                exit 1
            else
                echo "Running resampling script"
            fi
        elif [[ "$repairchoice" = "r" ]] || [[ "$repairchoice" = "R" ]]; then
            echo "Running resampling script"

        fi
    bash ${SAMPLING_RATE_SCRIPT}
    sr_exit_code=$?
    
    if [ $sr_exit_code -eq "0" ]; then
        echo "Resampling script completed successfully.  Dataset successfully sanitized."
        write_varfiles "$final_sampling_rate" 
        echo "press enter to continue"
        read
    fi

echo 

#If we made it this far, the dataset was good.
  
  
write_varfiles "$final_sampling_rate"
echo "wav_count" $wav_count
echo "all_count" $all_count
echo "core_count" $core_count
echo "max_workers" $max_workers
read
echo "wav_sampling_rate ${most_common_sampling_rate}" 
