#!/bin/bash
RESET='\033[0m' # Reset text color to default
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'

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
echo "  PIPER_PATH is set to $PIPER_PATH" 
echo "  PIPER_PATH can also be hardcoded by editing tts_dojo/newdojo.sh"
echo  
echo -e "  Dojo is ready! You will find it here:  ${CYAN}${DOJO_DIR}${RESET}"
echo
echo "  To use it, copy your dataset and pretrained .ckpt files to MY_FILES"
echo -e "  then run ${YELLOW}add_my_files.sh${RESET} from inside the new dojo directory."
echo -e "  After that, use ${YELLOW}start_training.sh${RESET} to guide you through the training process"
echo
echo
exit 0
