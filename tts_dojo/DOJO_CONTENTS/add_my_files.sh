#!/bin/bash

# Set a default value for SOURCE_FOLDER
DEFAULT_SOURCE_FOLDER="../MY_FILES"
echo
echo  "usage: add_my_files.sh /path/to/<YOUR_FILES>"
echo  "<YOUR_FILES> is a directory containing three things"
echo  "1.          wav - a directory with your training audio files"
echo  "2. metadata.csv - a transcription of all your training audio files"
echo  "3.  epoch*.ckpt - a partially trained TTS model"
echo 


# If a parameter is provided, use it as SOURCE_FOLDER
if [ $# -eq 1 ]; then
    SOURCE_FOLDER="$1"
else
    # If no parameter is provided, ask user if they want to use the default
    read -p "No source folder parameter provided. Use default folder ($DEFAULT_SOURCE_FOLDER)? (y/n): " USE_DEFAULT
    if [[ "$USE_DEFAULT" != "y" ]]; then
        echo "No valid source folder specified. Exiting."
        exit 1
    fi
    SOURCE_FOLDER="$DEFAULT_SOURCE_FOLDER"
fi

# Check if the source folder exists
if [ ! -d "$SOURCE_FOLDER" ]; then
    echo "Source folder '$SOURCE_FOLDER' does not exist. Exiting."
    exit 1
fi

ALLPRESENT=1

# Check for the WAV folder (case-insensitive)
if [ -z "$(find "$SOURCE_FOLDER" -maxdepth 1 -type d -iname "wav")" ]; then
    echo
    echo "WAV folder is missing from '$SOURCE_FOLDER'."
    echo "Please copy your dataset's training audio to $SOURCE_FOLDER/wav"
    ALLPRESENT=0
fi

# Check for CSV files (case-insensitive)
csv_files=$(find "$SOURCE_FOLDER" -iname "*.csv" 2>/dev/null)
if [ -z "$csv_files" ]; then
    echo
    echo "metadata.csv is missing in '$SOURCE_FOLDER'."
    echo "Please copy your dataset's metadata.csv file containing the text transcripts to $SOURCE_FOLDER/metadata.csv"
    ALLPRESENT=0
fi

# Check for CKPT files (case-insensitive)
ckpt_files=$(find "$SOURCE_FOLDER" -iname "*.ckpt" 2>/dev/null)
if [ -z "$ckpt_files" ]; then
    echo
    echo "No .CKPT files  were found in '$SOURCE_FOLDER'."
    echo "please copy a partially trained TTS model (eg. 'epoch=2307-step=558536.ckpt') into $SOURCE_FOLDER"
    echo "These can be found at https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main/en/en_US"
    ALLPRESENT=0
fi

# Exit if there were missing files
if [ "$ALLPRESENT" -eq 0 ]; then
    echo
    echo "Required files were missing.  Exiting"
    echo
    exit 1
fi

# Copy files to their expected locations
cp -r "$(find "$SOURCE_FOLDER" -maxdepth 1 -type d -iname "wav")" ./target_voice_dataset
cp $(find "$SOURCE_FOLDER" -iname "*.csv") ./target_voice_dataset
cp $(find "$SOURCE_FOLDER" -iname "*.ckpt") ./pretrained_tts_checkpoint

echo "Files copied successfully from $SOURCE_FOLDER."

