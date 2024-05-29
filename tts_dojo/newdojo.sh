#!/bin/bash
RESET='\033[0m' # Reset text color to default
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'



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


if [[ ! -e ".TEXTY_DIR" ]]; then
    echo "Path to TextyMcSpeechy directory not found in '.TEXTY_DIR'"
    echo "This is normally created by install_piper.sh" 
    exit 1
else
    TEXTY_DIR=$(cat ".TEXTY_DIR")

if [ ! -e ".BIN_DIR" ]; then
   echo ".BIN_DIR not present."
   echo "Normally it is created by install_piper.sh." 
   echo "and would contain /path/to/piper/src/python/.venv/bin"
   exit 1
else
    BIN_DIR=$(cat ".BIN_DIR")
fi    


PIPER_BIN="$BIN_DIR/piper"
# Check if the file 'piper' exists
if [[ -e "${PIPER_BIN}" ]]; then
    echo "OK    --  Piper binary found at path: $PIPER_BIN."
    echo
    
else
    echo "ERROR --  Piper binary not found in $BIN_DIR."
    echo "          Did you run install_piper.sh?"
    echo "Exiting."
    exit 1
fi


if [[ -n "$VIRTUAL_ENV" ]]; then
    echo
    echo "OK    --  Virtual environment is active in  $VIRTUAL_ENV"
    
elif [ -e "$BIN_DIR/activate" ]; then
   echo "Activating virtual environment."
   source $BIN_DIR/activate
else
    echo "ERROR --  No python virtual environment was found."
    echo
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
cp .TEXTY_DIR /.scripts
echo
echo  
echo -e "  Dojo is ready! You will find it here:  ${CYAN}${DOJO_DIR}${RESET}"
echo
echo "  To use it, copy your dataset and pretrained .ckpt files to MY_FILES"
echo -e "  then run ${YELLOW}add_my_files.sh${RESET} from inside the new dojo directory."
echo -e "  After that, use ${YELLOW}start_training.sh${RESET} to guide you through the training process"
echo
echo
exit 0
