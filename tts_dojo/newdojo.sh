#!/bin/bash

# Check if a parameter is provided
if [ -z "$1" ]; then
  echo
  echo 
  echo "Usage: $0 <VOICENAME>"
  echo "  Please supply a name for the voice being created."
  echo "  Training environment will be created in <VOICENAME>_dojo"
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
echo "Dojo created in : '$PWD/$DIRECTORY'"
echo "Populating with : '$PWD/DOJO_CONTENTS'"
cp -r ./DOJO_CONTENTS/* ./$DIRECTORY
cd $DIRECTORY

echo "$PIPER_BIN" > .PIPER_PATH
echo "$BIN_DIR" > .BIN_DIR

pwd > .DOJO_DIR
DOJO_DIR=$(cat .DOJO_DIR)
echo "Dojo complete."
echo "View $DIRECTORY/README.txt for next steps."
echo
exit 0
