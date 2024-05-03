#!/bin/bash
echo 
echo
echo
# Check if SPEAKER_ID was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <SPEAKER_ID>"
    echo
    echo "eg:  ./single_voice_from_VCTK_dataset.sh p222" 
    echo
    echo "Voices in the VCTK dataset have SPEAKER_ID's from p225 to p376"
    echo "see ./VCTK-Corpus-0.92/speaker-info.txt for characteristics of available speakers."
    echo
    echo
    echo
    exit 1
fi


SPEAKER_ID=$1  # Command line argument
PREFERRED_MIC='mic1'  # must be either `mic1` or `mic2`
VCTK_DIR="./VCTK-Corpus-0.92"
TXT_DIR="$VCTK_DIR/txt/$SPEAKER_ID"

# Check if the folder for SPEAKER_ID exists
if [ ! -d "$TXT_DIR" ]; then
    echo "Error: No such speaker directory '$TXT_DIR'."
    exit 1
fi


DESTINATION_DIR="${SPEAKER_ID}_dataset_original_voice"

echo "Creating single speaker dataset for $SPEAKER_ID in $DESTINATION_DIR"


# Prepare destination folder
mkdir $DESTINATION_DIR
mkdir -p "$DESTINATION_DIR/wav"
mkdir -p "$DESTINATION_DIR/txt"

echo "Copying files for $PREFERRED_MIC to $DESTINATION_DIR/wav"

# Copy one speaker's audio samples and text transcriptions
cp "$VCTK_DIR/wav48_silence_trimmed/$SPEAKER_ID/"*_"$PREFERRED_MIC".flac "$DESTINATION_DIR/wav"
cp "$VCTK_DIR/txt/$SPEAKER_ID/"* "$DESTINATION_DIR/txt"


echo "Creating metadata.csv from .txt transcriptions"

# Repackage transcriptions from individual text files into metadata.csv
cd "$DESTINATION_DIR"
ls txt/*.txt | while read TXT; do
    BASE=$(basename "$TXT" .txt)
    LINE=$(cat "$TXT")
    SPKR=$(echo "$BASE" | awk -F_ '{print $1}')
    if [ "$SPKR" == "$SPEAKER_ID" ]; then
        LINE=${LINE:1:-1}  # remove initial and final " in p225 data
    fi
    echo "${BASE}_$PREFERRED_MIC_output|0|$LINE"
done >> metadata.csv

echo "Done."

echo
echo "Please note that $DESTINATION_DIR/wav currently contains 48000Hz .flac files"
echo "These should be downsampled and converted to wav files prior to training a TTS model"
echo 
echo "If you are using Applio to morph the voice in these samples to another voice, you should"
echo "not downsample them until after that process is completed."
echo 
echo "use ./downsample_and_convert.sh --dataset_dir <dataset_dir> --sampling-rate [16000 or 22050]"
echo "to batch convert and downsample these datasets"
