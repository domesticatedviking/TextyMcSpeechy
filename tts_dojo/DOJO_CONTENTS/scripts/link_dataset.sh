#!/bin/bash
# scripts/link_dataset.sh  - Configures a voice_dojo to use an existing dataset

# path constants
DOJO_DIR="."       # path to <voice>_dojo 
TTS_DOJO_DIR=".."  # path to TextyMcSpeechy/tts_dojo
VARFILE_SAMPLING_RATE=".SAMPLING_RATE"
VARFILE_MAX_WORKERS=".MAX_WORKERS"
VARFILE_QUALITY="../target_voice_dataset/.QUALITY"
AUDIO_DIR_SYMLINK="../target_voice_dataset/wav"
DATASET_CONFIG_SYMLINK="../target_voice_dataset/dataset.conf" 
METADATA_PATH_SYMLINK="../target_voice_dataset/metadata.csv"
DEFAULT_CHECKPOINT_DIR_SYMLINK="../pretrained_tts_checkpoint/"
DATASET_DIR="../DATASETS"

# infer name of dojo and voice from directory name
DOJO_NAME=$(awk -F'/' '{print $(NF)}' <<< "$PWD")
VOICE_NAME=$(awk -F'/' '{print $(NF)}' <<< "$PWD" | sed 's/_dojo$//')

# initialize global vars
declare -a menu_items  
declare -a dataset_dirs
selected_dataset_dir=""
quality=""
qualitydir=""
menu_length=0
sampling_rate=0
conf_file_path=""


count_wav_files() {
# counts number of wav files in specified directory    
    local directory="$1"
    if [[ -z "$directory" ]]; then
        echo "Error: directory does not exist"
        return 1
    fi
    local count=$(find -L "$directory" -maxdepth 1 -type f \( -iname "*.wav" \) | wc -l)
    echo "$count"
}


get_max_workers() {
# calculates the max_workers parameter for piper preprocessing
# prevents Piper errors when preprocessing small datasets on high core count CPUs (closed issue #2)  
    local wav_count=$(count_wav_files $audio_dir)
    local core_count=$(nproc)
    if [ "$wav_count" -ge $((2 * $core_count)) ]; then
        max_workers=$core_count
        printf "%d" "$max_workers"
    else
        max_workers=$((wav_count / 4))
        printf "%d" "$max_workers"
    fi
}


write_varfile_max_workers(){
# writes parameter needed by Piper preprocessing to file 
    max_workers=$(get_max_workers)
    echo ${max_workers} > ${VARFILE_MAX_WORKERS}
  }


write_varfile_sampling_rate(){
# writes sampling rate needed by Piper training to file
    echo ${sampling_rate} > ${VARFILE_SAMPLING_RATE}
 }


write_varfile_quality(){
# writes voice quality setting needed by Piper training to file
    echo ${quality} > ${VARFILE_QUALITY}
 }


get_conf_values() {
# retrieves NAME and DESCRIPTION from voice dataset configuration file
    local conf_file=$1
    source "$conf_file"
    echo "$NAME|$DESCRIPTION"
}


populate_menu(){
# Loop to populate menu_items and dataset_dirs arrays
    index=1
    while IFS= read -r -d '' conf_file; do
        conf_values=$(get_conf_values "$conf_file")
        location=$(basename $(dirname $conf_file))
        IFS='|' read -r name description <<< "$conf_values"   # unpack multiple values from get_conf_values
        menu_items+=("$index)           Name: $name   \n      Description: $description   \n         location: DATASETS/$location \n")
        dataset_dirs+=("$(dirname "$conf_file")")
        ((index++))
        ((menu_length++))
    done < <(find "$DATASET_DIR" -type f -name "dataset.conf" -print0)
}


display_menu(){
# Show menu with list of datasets to choose from
    clear
    echo -e "Select a dataset to use for this dojo:\n"

    for item in "${menu_items[@]}"; do
        echo -e "$item"
    done
}


get_dataset_choice(){
# Prompts user to choose a voice dataset
    read -p "Enter the number of your choice: " choice

    # Validate choice and set selected_dataset_dir
    if [[ "$choice" -gt 0 && "$choice" -le "${#dataset_dirs[@]}" ]]; then
        selected_dataset_dir="${dataset_dirs[$((choice-1))]}"
        echo "You selected: $selected_dataset_dir"
    else
        echo "Invalid selection. Exiting."
        exit 1
    fi
}


get_quality_choice(){
# Prompts user to choose a voice quality
    clear
    answer=""
    echo -e  "Please select a quality level for the model that will be built in this dojo:\n"
    echo -e  "    [L]ow     - (use if generating speech on raspberry pi or other slower device)"
    echo -e  "    [M]edium"
    echo -e  "    [H]igh"
    echo
    echo -ne "     "
    while [ "$answer" = "" ]; do
        read quality
        quality="${quality^^}"
        if [ "$quality" == "L" ] || [ "$quality" == "M" ] || [ "$quality" == "H" ]; then
            answer="true"
        else
            echo -ne "    [L,M,H]? " 
        fi    
    done
}


relative_import_dataset_conf(){
# Builds relative path to conf file that will work in docker container, loads it on host
    conf_file_path="../../DATASETS/$(basename $selected_dataset_dir)/dataset.conf"
    cd scripts    # temporarily change dir so path above works in this script.
    source $conf_file_path
    cd ..  
}


find_default_checkpoint_dir(){
# expands stored quality setting and stores path to selected pretrained checkpoint
    if [ "$quality" = "L" ]; then
        qualitydir="low"
    elif [ "$quality" = "M" ]; then
        qualitydir="medium"
    elif [ "$quality" = "H" ]; then
        qualitydir="high" 
    else 
        echo "Error - invalid value for quality:  $quality"
        exit 1
    fi     
    default_checkpoint_dir="$TTS_DOJO_DIR/PRETRAINED_CHECKPOINTS/default/${DEFAULT_VOICE_TYPE}_voice/$qualitydir"
}


function find_default_checkpoint_file(){
# verifies that pretrained checkpoint file exists in PRETRAINED_CHECKPOINTS
# considered defaults because they can be overridden by files in <voice>_dojo/starting_checkpoint_override 

    echo -e "\n\nLooking for default checkpoint file in tts_dojo/PRETRAINED_CHECKPOINTS"
    echo -e "     quality [low, medium, high]  : $qualitydir"
    echo -e "     voice type [M,F]             : $DEFAULT_VOICE_TYPE\n"
    
    # Check if the default_checkpoint_dir variable is set
    if [ -z "$default_checkpoint_dir" ]; then
        echo "Error: default_checkpoint_dir is not set."
        return 1
    fi
    echo -e "  default_checkpoint_dir          : $default_checkpoint_dir"
    
    # Ensure the directory exists
    if [ ! -d "$default_checkpoint_dir" ]; then
        echo "Error: Directory $default_checkpoint_dir does not exist."
        return 1
    fi

    # Find all .ckpt files in the directory (there might be more than one)
    ckpt_files=("$default_checkpoint_dir"/*.ckpt)

    # Check the number of .ckpt files found
    if [ ${#ckpt_files[@]} -eq 0 ]; then
        echo -e "Error: No .ckpt files found in $default_checkpoint_dir."
        echo 
        echo -e "Please run tts_dojo/PRETRAINED_CHECKPOINTS/download_defaults.sh"
        echo -e "for instructions on how to continue."
        echo -e "Exiting."
        exit 1
    elif [ ${#ckpt_files[@]} -gt 1 ]; then
        echo "Error: Multiple .ckpt files found in $default_checkpoint_dir."
        echo "Please ensure there is only one '.ckpt' file in that directory"
        echo "Exiting."
        exit 1
    else
        default_checkpoint_path=${ckpt_files[0]}
        echo "Default checkpoint file found:" 
        echo "        $default_checkpoint_path"
        echo
        return 0
    fi
}

# 
get_relative_path_of_pretrained_checkpoint() {
# converts absolute path to a pretrained checkpoint to a relative path that will work in both docker container and host
    local full_path="$1"
    local relative_path="../..$(echo "$full_path" | sed -E 's|^.*(/PRETRAINED_CHECKPOINTS/)|\1|')"
    echo "$relative_path"
}

relative_find_default_checkpoint_file(){
# attempts to locate a default pretrained checkpoint file and stores it as relative path.
    find_default_checkpoint_file  
    relative_default_checkpoint_path="$(get_relative_path_of_pretrained_checkpoint "$default_checkpoint_path")"
    default_checkpoint_path=$relative_default_checkpoint_path
}

remove_varfiles(){
# purges dojo of variable files created in prior runs
   rm $VARFILE_MAX_WORKERS >/dev/null 2>&1
   rm $VARFILE_SAMPLING_RATE >/dev/null 2>&1
   rm $VARFILE_QUALITY >/dev/null 2>&1
}

write_varfiles(){
# stores all values needed by other scripts in hidden files
   write_varfile_max_workers
   write_varfile_sampling_rate
   write_varfile_quality
}

remove_existing_symlink(){
# deletes symlinks but leaves real files and directories alone
    local link="$1"
    local type_text="file"
    
    if [[ -e "$link" ]]; then           # check if file exists
        if [[ -d "$link" ]]; then        # check if file is directory
            type_text="directory"
        fi
        if [[ -L "$link" ]]; then       # check if file is a symlink
            rm $link
            return 0                    # remove link if found

        else
            echo "    Error removing symbolic link.  Item found was not a symbolic link, but contains real data."
            echo "    location:  $link"
            echo "    Cannot proceed unless $type_text is deleted or manually moved out of the dojo."
            echo            
       fi
   fi
}
                
                
remove_previous_checkpoint(){
# Checks a specified directory for existence of any checkpoint file and asks for permission to delete it
    local directory="$1"
    checkpoint=""
    
    # Check if directory exists
    if [[ -d "$directory" ]]; then
        # Find the first .ckpt file in the directory
        checkpoint=$(find "$directory" -maxdepth 1 -type f -name "*.ckpt" | head -n 1)
    else
        echo "Directory does not exist: $directory"
    fi
    
    if [ -z "$checkpoint" ] || [ -L "$checkpoint" ]; then   #if file doesn't exist or is a symlink, do nothing
        return 0
    fi
    
    echo "Found a real checkpoint file in $checkpoint which must be removed to proceed."
    echo -ne "    would you like to [D]elete it or [Q]uit?  "
    read choice
    choice=${choice^^}
    if [ "$choice" = "D" ]; then
        rm $checkpoint
    else
        echo "Exiting."
        exit 1
    fi    
}          
            

relative_link_files(){ 
# Symlinks must function correctly in both the host and docker container.
#   1. in the docker container, TextyMcSpeechy/tts_dojo is mounted at /apps/tts_dojo 
#   2. on the host machine, it is mounted at /path/to/TextyMcSpeechy/tts_dojo
#   All paths used by both host and container code must be relative to <voice>_dojo/scripts
 
    dataset_path_relative="../../DATASETS/$(basename $selected_dataset_dir)"
    
    # configure dataset paths and sampling rates relevant to chosen quality setting
    audio_dir=""
    if [ "$quality" = "L" ]; then
        audio_dir="$dataset_path_relative"/"$LOW_AUDIO"
        sampling_rate=16000
    elif [ "$quality" = "M" ]; then
        audio_dir="$dataset_path_relative"/"$MEDIUM_AUDIO"
        sampling_rate=22050
    elif [ "$quality" = "H" ]; then
        audio_dir="$dataset_path_relative"/"$HIGH_AUDIO"
        sampling_rate=22050
    fi

    # build path to dataset's metadata.csv file
    metadata_path="$dataset_path_relative/metadata.csv"

    echo
    echo "Source audio directory         : $audio_dir"
    echo "metadata.csv location          : $metadata_path"
    echo "pretrained checkpoint location : $default_checkpoint_path"
    echo "dataset.conf path              : $conf_file_path"
    echo
    echo "Creating relative symbolic links in your dojo."
    echo
     
    cd scripts # paths stored by this script are relative to <voice>_dojo/scripts so this is necessary here   
    
    # Create symlink for relevant audio directory of dataset inside dojo  
    if [ -d "$audio_dir" ]; then
        $(remove_existing_symlink "$AUDIO_DIR_SYMLINK")
        ln -s "$audio_dir" "$AUDIO_DIR_SYMLINK"
    else
        echo "Error: audio directory $audio_dir does not exist."
    fi

    # Create symlink for dataset's metadata.csv inside dojo
    if [ -f "$metadata_path" ]; then
        $(remove_existing_symlink "$METADATA_PATH_SYMLINK")
        ln -s "$metadata_path" "$METADATA_PATH_SYMLINK" 
    else
        echo "Error: metadata file  $metadata_path does not exist."
    fi
    
    # Create symlink for dataset's configuration file inside dojo
    if [ -f "$conf_file_path" ]; then
        $(remove_existing_symlink "$DATASET_CONFIG_SYMLINK")
        ln -s "$conf_file_path" "$DATASET_CONFIG_SYMLINK" 
    else
        echo "WARNING: dataset configuration file $conf_file_path does not exist."
    fi

    # Remove any existing checkpoint files from dojo
    checkpoint_filename=$(basename $default_checkpoint_path)
    checkpoint_symlink="${DEFAULT_CHECKPOINT_DIR_SYMLINK}""${checkpoint_filename}"
    remove_previous_checkpoint $DEFAULT_CHECKPOINT_DIR_SYMLINK  #don't know its name so need function to find it.
    $(remove_existing_symlink "$checkpoint_symlink")
    
    # Create symlink for default checkpoint file in dojo
    if [ -f "$default_checkpoint_path" ]; then
        ln -s "$default_checkpoint_path" "$checkpoint_symlink"
    else
        echo "Error: default checkpoint path file $default_checkpoint_path does not exist."
    fi
    echo "Symbolic links created successfully."
}


# MAIN PROGRAM
populate_menu
if [ "$menu_length" = "0" ]; then
    echo -e "No datasets configured."
    echo -e "Run tts_dojo/DATASETS/create_dataset.sh"
fi
display_menu
get_dataset_choice
relative_import_dataset_conf
get_quality_choice
find_default_checkpoint_dir
relative_find_default_checkpoint_file
relative_link_files
write_varfiles
