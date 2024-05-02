 #!/bin/bash
# This script creates a directory with the given VOICENAME followed by "_dojo"

# Check if a parameter is provided
if [ -z "$1" ]; then
  echo "Error: No VOICENAME provided."
  echo "Usage: $0 <VOICENAME>"
  exit 1
fi

# Use the provided parameter to create the directory name
VOICENAME="$1"
DIRECTORY="${VOICENAME}_dojo"

# Check if the directory already exists
if [ -d "$DIRECTORY" ]; then
  echo "Error: Directory '$DIRECTORY' already exists."
  exit 1
fi

# Create the new directory
mkdir "$DIRECTORY"

# Confirm success
echo
echo "Dojo has been created in '$PWD/$DIRECTORY'."
echo
echo "Populating dojo with contents of '$PWD/DOJO_CONTENTS'"
cp -r ./DOJO_CONTENTS/* ./$DIRECTORY
echo
echo "Next steps."
echo "1. Copy target voice dataset into '$PWD/$DIRECTORY/target_voice_dataset'"
echo "2. Copy pretrained TTS .ckpt file into '$PWD/$DIRECTORY/pretrained_tts_checkpoint'"
echo "3. run ' bash 1_preprocess.sh ' from inside the dojo directory and await further instructions"




