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

#relative paths require this script to run from $DOJO_DIR
cd $DOJO_DIR


TTS_DOJO_DIR=$(dirname $DOJO_DIR)
echo "TTS_DOJO_DIR= $TTS_DOJO_DIR"



dataset_dir="$TTS_DOJO_DIR"/"DATASETS"

declare -a menu_items
declare -a dataset_dirs
selected_dataset_dir=""
quality=""
menu_length=0
sampling_rate=0
conf_file_path=""
VARFILE_SAMPLING_RATE="${DOJO_DIR}/scripts/.SAMPLING_RATE"
VARFILE_MAX_WORKERS="${DOJO_DIR}/scripts/.MAX_WORKERS"
VARFILE_QUALITY="${DOJO_DIR}/target_voice_dataset/.QUALITY"
AUDIO_DIR_SYMLINK="./target_voice_dataset/wav"
DATASET_CONFIG_SYMLINK="./target_voice_dataset/dataset.conf" 
METADATA_PATH_SYMLINK="./target_voice_dataset/metadata.csv"
DEFAULT_CHECKPOINT_DIR_SYMLINK="./pretrained_tts_checkpoint/"

count_wav_files() {
    local directory="$1"

    if [[ -z "$directory" ]]; then
        echo "Error: directory does not exist"
        return 1
    fi

    local count=$(find -L "$directory" -maxdepth 1 -type f \( -iname "*.wav" \) | wc -l)
    echo "$count"
}


get_max_workers() {
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
    #calculate and write max_workers
    max_workers=$(get_max_workers)
    echo ${max_workers} > ${VARFILE_MAX_WORKERS}
  }

write_varfile_sampling_rate(){
    echo ${sampling_rate} > ${VARFILE_SAMPLING_RATE}
 }
 
write_varfile_quality(){
    echo ${quality} > ${VARFILE_QUALITY}
 }




# Function to read NAME and DESCRIPTION from default.conf
get_conf_values() {
    local conf_file=$1
    source "$conf_file"
    echo "$NAME|$DESCRIPTION"
}

# Populate menu_items and dataset_dirs arrays
populate_menu(){
index=1
while IFS= read -r -d '' conf_file; do
    conf_values=$(get_conf_values "$conf_file")
    location=$(basename $(dirname $conf_file))
    IFS='|' read -r name description <<< "$conf_values"   # unpack multiple values from get_conf_values
    menu_items+=("$index)           Name: $name   \n      Description: $description   \n         location: DATASETS/$location \n")
    dataset_dirs+=("$(dirname "$conf_file")")
    ((index++))
    ((menu_length++))
done < <(find "$dataset_dir" -type f -name "dataset.conf" -print0)

}

# Display the menu
display_menu(){
clear
echo -e "Select a dataset to use for this dojo:\n"

for item in "${menu_items[@]}"; do
    echo -e "$item"
done

}

# Read user selection
get_dataset_choice(){
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

#echo "Selected quality level was:  $quality"

}



import_dataset_conf(){
conf_file_path="$selected_dataset_dir"/dataset.conf
source $conf_file_path
#echo "name: $NAME"
#echo "description: $DESCRIPTION"
#echo "voice type :$DEFAULT_VOICE_TYPE"
#echo "low audio: $LOW_AUDIO"
#echo "med audio: $MEDIUM_AUDIO"
#echo "high audio: $HIGH_AUDIO"
#read
}

find_default_checkpoint_dir(){
#echo "Checking whether PRETRAINED_CHECKPOINTS contains any appropriate defaults."
qualitydir=""
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


#echo "location for pretrained checkpoint:  $default_checkpoint_dir"
}


function find_default_checkpoint_file(){
    echo -e "\n\nLooking for default checkpoint file in tts_dojo/PRETRAINED_CHECKPOINTS"
    echo -e "     quality [low, medium, high]  : $qualitydir"
    echo -e "     voice type [M,F]             : $DEFAULT_VOICE_TYPE\n"
    
    # Check if the default_checkpoint_dir variable is set
    if [ -z "$default_checkpoint_dir" ]; then
        echo "Error: default_checkpoint_dir is not set."
        return 1
    fi

    # Ensure the directory exists
    if [ ! -d "$default_checkpoint_dir" ]; then
        echo "Error: Directory $default_checkpoint_dir does not exist."
        return 1
    fi

    # Find .ckpt files in the directory
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

remove_varfiles(){
   rm $VARFILE_MAX_WORKERS >/dev/null 2>&1
   rm $VARFILE_SAMPLING_RATE >/dev/null 2>&1
   rm $VARFILE_QUALITY >/dev/null 2>&1
}


write_varfiles(){
   write_varfile_max_workers
   write_varfile_sampling_rate
   write_varfile_quality
}



remove_existing_symlink(){
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
            
         







link_files(){


audio_dir=""

if [ "$quality" = "L" ]; then
    audio_dir="$selected_dataset_dir"/"$LOW_AUDIO"
    sampling_rate=16000
elif [ "$quality" = "M" ]; then
    audio_dir="$selected_dataset_dir"/"$MEDIUM_AUDIO"
    sampling_rate=22050
elif [ "$quality" = "H" ]; then
    audio_dir="$selected_dataset_dir"/"$HIGH_AUDIO"
    sampling_rate=22050
fi

metadata_path="$selected_dataset_dir"/"metadata.csv"

echo
echo "Source audio directory         : $audio_dir"
echo "metadata.csv location          : $metadata_path"
echo "pretrained checkpoint location : $default_checkpoint_path"
echo
echo "Creating symbolic links in your dojo."






if [ -d "$audio_dir" ]; then
  $(remove_existing_symlink "$AUDIO_DIR_SYMLINK")
  ln -s "$audio_dir" "$AUDIO_DIR_SYMLINK"
else
  echo "Error: Directory $audio_dir does not exist."
fi

if [ -f "$metadata_path" ]; then
  $(remove_existing_symlink "$METADATA_PATH_SYMLINK")
  ln -s "$metadata_path" "$METADATA_PATH_SYMLINK" 
else
  echo "Error: File $metadata_path does not exist."
fi


if [ -f "$conf_file_path" ]; then
  $(remove_existing_symlink "$DATASET_CONFIG_SYMLINK")
  ln -s "$conf_file_path" "$DATASET_CONFIG_SYMLINK" 
else
  echo "Error: File $conf_file_path does not exist."
fi


# Symlinking the checkpoint file requires an extra step because its name isn't always the same.
checkpoint_filename=$(basename $default_checkpoint_path)
checkpoint_symlink="${DEFAULT_CHECKPOINT_DIR_SYMLINK}""${checkpoint_filename}"
  remove_previous_checkpoint $DEFAULT_CHECKPOINT_DIR_SYMLINK  #don't know its name so need function to find it.
  $(remove_existing_symlink "$checkpoint_symlink")
#echo "Checkpoint symlink is:  $checkpoint_symlink"


if [ -f "$default_checkpoint_path" ]; then
  ln -s "$default_checkpoint_path" "$checkpoint_symlink"
else
  echo "Error: File $default_checkpoint_path does not exist."
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
import_dataset_conf
get_quality_choice
find_default_checkpoint_dir
find_default_checkpoint_file
link_files
write_varfiles





