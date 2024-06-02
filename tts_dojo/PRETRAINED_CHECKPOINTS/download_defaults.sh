#!/bin/bash

# URL downloader for pretrained piper checkpoint files
# Feel free to replace the links below with your preferred languages and voices, or manually download and copy these files into their respective folders.
# Please be aware that all quality levels are not available for all voices, and there are no en_US options for low quality feminine voices.

# You will find all available options here:  https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main
 

# Low, medium, and high quality piper checkpoints for traditionally masculine "lessac" voice (en_US)
                   
DEFAULT_M_LOW_URL="https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/lessac/low/epoch%3D2307-step%3D558536.ckpt?download=true"
DEFAULT_M_MED_URL="https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/lessac/medium/epoch%3D2164-step%3D1355540.ckpt?download=true"
DEFAULT_M_HIGH_URL="https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/lessac/high/epoch%3D2218-step%3D838782.ckpt?download=true"

# Low, medium, and high quality piper checkpoints for tradionally feminine voice (en_US)
DEFAULT_F_LOW_URL="https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/lessac/low/epoch%3D2307-step%3D558536.ckpt?download=true"  # sadly no pretrained "low" models for F voices are available.
DEFAULT_F_MED_URL="https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/amy/medium/epoch%3D6679-step%3D1554200.ckpt?download=true"  # amy_medium
DEFAULT_F_HIGH_URL="https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/ljspeech/high/ljspeech-2000.ckpt?download=true" #ljspeech high




# Code below dowloads the links above into the appropriate folders.


M_URLS=( "$DEFAULT_M_LOW_URL" "$DEFAULT_M_MED_URL" "$DEFAULT_M_HIGH_URL")
F_URLS=( "$DEFAULT_F_LOW_URL" "$DEFAULT_F_MED_URL" "$DEFAULT_F_HIGH_URL")

PRETRAINED_TTS_DIR=$(pwd)

get_filename_from_url() {
    local url="$1"
    local filename=""

    # Extract the filename from the URL
    filename=$(basename "$url")
    
    # strip ?download=true
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
        #wget -P "$PRETRAINED_TTS_DIR/$subfolder/$quality/"  $url
    fi
done

}


download_urls "default/M_voice" "${M_URLS[@]}"

download_urls "default/F_voice" "${F_URLS[@]}"

