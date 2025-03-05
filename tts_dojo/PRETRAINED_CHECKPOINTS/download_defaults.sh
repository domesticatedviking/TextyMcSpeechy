#!/bin/bash

# URL downloader for pretrained piper checkpoint files
# Feel free to replace the links below with your preferred languages and voices, or manually download and copy these files into their respective folders.

# A good place to find pretrained checkpoints is:  https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main

set +e  # terminate on error

# Directory containing the language files
LANG_DIR="languages"

PRETRAINED_LANGUAGE_VARFILE="default/.ESPEAK_LANGUAGE"

# Array to store language filenames without extensions
languages=()
conf_file=$1
available_checkpoints=""

check_language() {
    local language_string="$1"
    local found=0

    for language in "${languages[@]}"; do
        if [[ "$language" == "$language_string" ]]; then
            found=1
            break
        fi
    done

    if [[ ! $found -eq 1 ]]; then
        echo "Invalid language string:  '$language_string'.  Exiting."
        exit 1
    fi
}

load_language_options(){
# Read files in the directory and store filenames without extensions in the array
for file in "$LANG_DIR"/*.conf; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file" .conf)
        languages+=("$filename")
    fi
done
}

# Output all languages
print_language_options(){
for language in "${languages[@]}"; do
    echo "        $language"
done
}


# Check if language parameter is passed
if [ -z "$1" ]; then
    load_language_options
    echo "No language specified. Usage: $0 <language>"
    echo 
    echo "    available options for <language> are:"
    print_language_options
    echo
    echo "To add a language, use .conf files in the languages directory as a template."
    echo "Pull requests will be received with gratitude."
    echo
    echo "You can also manually add your checkpoint files to the appropriate folders in 'PRETRAINED_CHECKPOINT_FILES/default' if you prefer."
    exit 1
fi

# Store the language parameter in requested_language variable
requested_language="$1"
load_language_options
check_language "$requested_language"
source "./languages/""$requested_language.conf"


# Code below downloads the links above into the appropriate folders.

M_URLS=( "$DEFAULT_M_LOW_URL" "$DEFAULT_M_MED_URL" "$DEFAULT_M_HIGH_URL")
F_URLS=( "$DEFAULT_F_LOW_URL" "$DEFAULT_F_MED_URL" "$DEFAULT_F_HIGH_URL")

PRETRAINED_TTS_DIR=$(pwd)

get_filename_from_url() {
    local url="$1"
    local filename=""

    # Extract the filename from the URL
    filename=$(basename "$url")
    
    # Strip ?download=true
    filename=$(echo "$filename" | cut -d'?' -f1)
    
    # Decode URL-encoded characters
    filename=$(echo "$filename" | sed 's/%3D/=/g' | sed 's/%20/ /g' | sed 's/%2C/,/g')

    echo "$filename"
}

get_quality_from_url() {
    local url="$1"
    local path=""
    local parent_folder=""

    # Extract the path from the URL by removing the protocol and domain
    path="${url#https://*/}"
    path="${path#*/}"

    # Extract the directory path
    path=$(dirname "$path")

    # Get the parent folder
    parent_folder=$(basename "$path")

    echo "$parent_folder"
}


build_conforming_filename() {
    # Accept the filename as input
    local original_name="$1"

    # Check if the filename ends with .ckpt, exit if not
    if [[ ! "$original_name" =~ \.ckpt$ ]]; then
        echo "Error: Filename must end with .ckpt"
        return 1
    fi

    # Extract integers greater than 10 from the filename using regex
    local integers=$(echo "$original_name" | grep -oE '[0-9]{2,}')
    
    # Convert the list of integers to an array
    IFS=$'\n' read -rd '' -a arr <<< "$integers"
    
    # Sort the integers in ascending order
    IFS=$'\n' sorted_integers=($(sort -n <<<"${arr[*]}"))
    
    # Set default values
    local integer_1=1000
    local integer_2=11111111

    # Get integer_1 (smallest value) and integer_2 (largest value)
    if [[ ${#sorted_integers[@]} -gt 0 ]]; then
        integer_1="${sorted_integers[0]}"
        if [[ ${#sorted_integers[@]} -gt 1 ]]; then
            integer_2="${sorted_integers[-1]}"
        fi
    fi

    # Output the new filename format
    echo "epoch=$integer_1-step=$integer_2.ckpt"
}


validate_checkpoint_filename() {
    local filename="$1"
    if [[ "$filename" =~ ^epoch=[0-9]+-step=[0-9]+\.ckpt$ ]]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
}



fix_checkpoint_filename() {
    local filename="$1"
    local fixed=""
    local fixed_conforms=""
    conforms=$(validate_checkpoint_filename $filename)
    if [[ "$conforms" == "PASS" ]]; then
        echo "$filename"  # filename provided conforms
    else
        fixed=$(build_conforming_filename $filename)
        fixed_conforms=$(validate_checkpoint_filename $fixed)
        if [[ "$fixed_conforms" == "PASS" ]]; then
            echo $fixed
        else
            echo "ERROR.  Unable to create a conforming filename from:  $filename."
            echo "                          attempted fix resulted in:  $fixed" 
            exit 1
        fi
    fi

}

download_urls(){
    local subfolder="$1"  # folder within pretrained folder eg defaults/m_voices
    shift
    local url_array=("${@}") 
    local filename=""
    local quality=""
    local url=""
    local voice_string=""
    local voice_type=""
    
    
    for url in "${url_array[@]}"; do       
        filename=$(get_filename_from_url "$url")
        quality=$(get_quality_from_url "$url")
        voice_string=$(basename $subfolder) # extract voice folder name   
        voice_type="${voice_string%_voice}" # remove _voice to get M or F

        if [[ -n $filename ]] && [[ -n $url ]]; then
            validname=$(fix_checkpoint_filename "$filename")
            echo
            echo "***********************************************************************"
            echo " A URL for ${voice_type}_voice, $quality quality was supplied by $conf_file.conf "
            echo

            if [ -e "$PRETRAINED_TTS_DIR/$subfolder/$quality/$validname" ]; then
                echo -e "\n$subfolder/$quality/$validname already exists.  Not downloading."
                echo
                echo
                available_checkpoints+="            ${voice_type} - ${quality} quality"$'\n'   # build summary of available combinations 
            else
                echo -e "Attempting to download from source:"
                echo -e "    $url"
                echo -e "destination: $subfolder/$quality/$validname."

                if wget -O "$PRETRAINED_TTS_DIR/$subfolder/$quality/$validname" "$url"; then
                    available_checkpoints+="            ${voice_type} - ${quality} quality"$'\n' # build summary of available combinations
                else
                    echo "Download failed: $url" >&2
                    available_checkpoints+="            ${voice_type} - ${quality} quality --- DOWNLOAD FAILED"$'\n' # build summary of available combinations
                fi
            fi
        else
            if [[ -n $url ]]; then
                echo "Url provided was: $url"
                echo "No download available for voice type $(basename $subfolder) at quality level $quality"
            fi

        fi
    done
}

download_urls "default/M_voice" "${M_URLS[@]}"
download_urls "default/F_voice" "${F_URLS[@]}"

if [ ! -z $ESPEAK_LANGUAGE ]; then
    echo $ESPEAK_LANGUAGE > $PRETRAINED_LANGUAGE_VARFILE 
else
    echo "Warning: no value for ESPEAK_LANGUAGE provided by '$requested_language.conf'"
fi
echo
echo
echo
echo
echo "SUMMARY OF AVAILABLE PRETRAINED CHECKPOINTS - PLEASE READ"
echo
echo "    $conf_file.conf included pretrained checkpoints for the following combinations of voice type and quality level:"
echo
echo -n "$available_checkpoints"
echo


echo "    If the combination of voice type and quality level you wish to use is not listed, your options are to:"
echo "        - train from scratch"
echo "        - copy any properly named .ckpt file to the correct subfolder matching its voice type and quality level within PRETRAINED_CHECKPOINTS/default"
echo "        - the .ckpt file must be named using this pattern (any name in this pattern will work, pattern is case sensitive):"
echo "                          epoch=1000-step=11111111111.ckpt"
echo "        - you can download a .ckpt from another language at https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main"
echo "        - you can also use any the .ckpt files generated by your own training sessions (saved in your voice dojo's voice_checkpoints folder)"  
echo
echo "Exiting."
