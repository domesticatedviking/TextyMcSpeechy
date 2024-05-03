#!/bin/bash

PIPER_PATH="" # /path/to/piper (the place where you cloned the repo)

# Check if a parameter is provided
if [ -z "$1" ]; then
  echo
  echo 
  echo "Usage: $0 <VOICE_NAME>"
  echo "  Please supply a name for the voice being created."
  echo "  Training environment will be created in <VOICE_NAME>_dojo"
  echo
  echo "Exiting."
  echo
  exit 1
fi

if [[ -n "$VIRTUAL_ENV" ]]; then
    echo
    echo "OK    --  Virtual environment is active in  $VIRTUAL_ENV"
    
else
    echo "ERROR --  No python virtual environment is active."
    echo "  to activate it, use:   source/<PATH/TO/VIRTUAL_ENVIRONMENT>/bin/activate"
    echo "  then run this script again."
    echo
    echo "Exiting."
    exit 1
fi

BIN_DIR="$VIRTUAL_ENV/bin"
PIPER_BIN="$BIN_DIR/piper"
# Check if the file 'piper' exists
if [[ -e "${PIPER_BIN}" ]]; then
    echo "OK    --  Piper binary found at path: $PIPER_BIN."
    echo
    
else
    echo "ERROR --  Piper binary not found in $BIN_DIR."
    echo "          Was Piper installed in this virtual environment?"
    echo "Exiting."
    exit 1
fi



# Use the provided parameter to create the directory name
VOICE_NAME="$1"
DIRECTORY="${VOICE_NAME}_dojo"




# Check if the directory already exists
if [ -d "$DIRECTORY" ]; then
  echo "Error: Directory '$DIRECTORY' already exists."
  exit 1
fi

# Create the new directory
mkdir "$DIRECTORY"

# Confirm success
echo "Dojo created in : '$PWD/$DIRECTORY'"
echo "Populating with : '$PWD/DOJO_CONTENTS'"
cp -r ./DOJO_CONTENTS/* ./$DIRECTORY
cd $DIRECTORY

echo "$VOICE_NAME" > .VOICE_NAME
echo "$BIN_DIR" >  .BIN_DIR
pwd > .DOJO_DIR
DOJO_DIR=$(cat .DOJO_DIR)

# If PIPER_PATH is still empty, attempt to infer it from BIN_DIR
if [ -z "$PIPER_PATH" ]; then
    # Extract /path/to/piper/
    PIPER_PATH=$(echo "$BIN_DIR" | grep -oP "^.+?/piper/")
fi

echo "$PIPER_PATH" >.PIPER_PATH
cp .PIPER_PATH ./scripts
cp .BIN_DIR ./scripts
cp .DOJO_DIR ./scripts
cp .VOICE_NAME ./scripts
echo
echo "/path/to/piper is inferred to be at: $PIPER_PATH" 
echo
echo "  For this inference to work properly your venv folder must be in /piper/src/python "
echo "  PIPER_PATH can also be hardcoded by editing tts_dojo/newdojo.sh"
echo  
echo "Dojo complete."
echo "View $DIRECTORY/README.txt for next steps."
echo
exit 0
