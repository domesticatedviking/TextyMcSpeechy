#!/bin/bash
# Setup for dockerized piper build
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m' # Reset text color to default
TEXTY_PATH=$(pwd)

# Define an error handler
error_handler() {
  echo -e "${RED}An error occurred during the installation. Exiting.${RESET}"
}

# Set up the error trap to run the error handler on any error
trap error_handler ERR

# Exit on error
set -e

echo
echo
echo
echo -e "${GREEN}   TextyMcspeechy setup${RESET}"
echo 
echo -e "   This script will prepare the TextyMcSpeechy TTS dojo for its first run by:"
echo -e "       - Verifying that docker is installed on your system"
echo -e "       - Getting the textymcspeechy-piper docker image needed for training"
echo -e "       - Installing packages needed by the TTS dojo."
echo

echo -ne "${YELLOW}Would you like to [i]nstall or [q]uit?${RESET}  "
read choice
if [ "$choice" != "i" ] && [ "$choice" != "I" ]; then
    echo 
    echo "Exiting."
    echo
    echo
    echo
    exit 0
fi

echo "Checking if the image already exists.  press <Enter>."
read
echo "TMS_USER_ID=$(id -u) TMS_GROUP_ID=$(id -g) docker compose build is the command that would be used to build the container if this is real "



# Check if the script has root access before using sudo
echo
echo -e "${YELLOW}The tts dojo requires tmux, ffmpeg, inotify-tools and sox packages.  This requires sudo privileges${RESET}"
echo "these are fake commands"
echo "sudo apt-get update"
echo "sudo apt-get install espeak-ng tmux ffmpeg inotify-tools"

# If everything went well, print the success message
#cd "$TEXTY_PATH"
#echo "$TEXTY_PATH" > "tts_dojo/.TEXTY_DIR"
echo -e "${GREEN}All done.${RESET}"
echo

