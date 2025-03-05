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

download_urls(){
    local subfolder="$1"  # folder within pretrained folder eg defaults/m_voices
    shift
    local url_array=("${@}") 
    local filename=""
    
    for url in "${url_array[@]}"; do
        filename=$(get_filename_from_url "$url")
        quality=$(get_quality_from_url "$url")

        if [ -e "$PRETRAINED_TTS_DIR/$subfolder/$quality/$filename" ]; then
            echo -e "\n$subfolder/$quality/$filename already exists.  Not downloading."
        else
            echo -e "\nDownloading $filename to $subfolder/$quality."
            wget -O "$PRETRAINED_TTS_DIR/$subfolder/$quality/$filename"  $url
        fi
    done
}
clear
echo "Warning: At present this script provides only partial assistance downloading pretrained checkpoint files."
echo "Some of the recently added .conf files include filenames that do not fit previous naming conventions."
echo "textymcspeechy currently requires .ckpt files to be named according to the following pattern:"
echo "eg:     epoch=1234-step=1234567890.ckpt"
echo "A fix will be coming soon, but in the meantime you will need to rename any files that do not comply."
echo "Also keep in mind that pretrained checkpoints are not necessarily available for all voice types and quality levels"
echo "Please check PRETRAINED_CHECKPOINTS/default subfolders for a properly named .ckpt file before training your model"
echo
echo "Press <Enter>"
read

download_urls "default/M_voice" "${M_URLS[@]}"
download_urls "default/F_voice" "${F_URLS[@]}"

if [ ! -z $ESPEAK_LANGUAGE ]; then
    echo "Configured espeak language: $ESPEAK_LANGUAGE "
    echo $ESPEAK_LANGUAGE > $PRETRAINED_LANGUAGE_VARFILE 
else
    echo "Warning: no value for ESPEAK_LANGUAGE provided by '$requested_language.conf'"
fi

echo
echo "Since pretrained checkpoints might not be available for all quality levels and voice types,"
echo "  please check the subfolders of PRETRAINED_CHECKPOINTS/default  "
echo "  to ensure that a .ckpt file is available for your desired voice type and quality level before you start training."
echo "If no .ckpt file is available, you can either train from scratch, or copy a .ckpt from a different language into the relevant folder."
echo "You can also use .ckpt files generated during your own training sessions (found in dojo's voice_checkpoints folder) as pretrained checkpoints."
echo
echo "A collection of pretrained checkpoints can be found at https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main"
