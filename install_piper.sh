#!/bin/bash
# Known to work with Piper commit: a0f09cdf9155010a45c243bc8a4286b94f286ef4
# Define color variables
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
echo -e "${GREEN}Piper installer${RESET}"
echo 
echo -e "   This script will install Piper into "$TEXTY_PATH"/piper"
echo -e "   It will also create a python 3.10 venv in ${YELLOW}/piper/src/python/.venv${RESET}"
echo -e "   where it will install the dependencies needed to train TTS models"
echo
echo -e "   If you prefer to use an existing installation, create a symlink to"
echo -e "   your piper directory in ${YELLOW}$TEXTY_PATH/piper${RESET}."
echo
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




# Check if piper is already installed
if [ -d "piper" ]; then
  echo -ne "${YELLOW}piper is already installed. Do you want to re-install it? (y/n) ${RESET}" 
  read choice
  if [ "$choice" != "y" ]; then
    echo "Exiting without re-installing piper."
    exit 0
  fi
  echo "Removing existing piper installation.  This action requires sudo privileges"
  sudo rm -r piper  # Re-clone if user chooses to reinstall
  echo "Removed existing piper directory."
fi

# Clone piper
echo
echo "Cloning piper..."
echo
git clone https://github.com/rhasspy/piper.git

cd piper/src/python

# Check if Python 3.10 is installed
if ! command -v python3.10 &> /dev/null; then
  echo -e "${RED}Python 3.10 is not installed. Please install it to proceed.${RESET}"
  exit 1
fi

# Create and activate virtual environment
echo
echo "Creating Python 3.10 virtual environment..."
python3.10 -m venv .venv
echo

#

source .venv/bin/activate
echo "Activated virtual environment."

# Update pip and install packages
pip install --upgrade pip wheel setuptools
echo "Updated pip, wheel, setuptools."

pip install piper-tts
pip install build
python -m build

pip install -e .
pip install -r requirements.txt

bash ./build_monotonic_align.sh
pip install torchmetrics==0.11.4


# Check if the script has root access before using sudo
echo
echo -e "${YELLOW}About to install 'espeak-ng, tmux, ffmpeg, inotify-tools' packages.  This requires sudo privileges${RESET}"
echo
sudo apt-get update
sudo apt-get install espeak-ng tmux ffmpeg inotify-tools

# If everything went well, print the success message
cd "$TEXTY_PATH"
va="activating_venv_README.txt"
echo
echo
echo "Creating '$va' as a reminder of how to activate the python .venv"
echo " " > $va
echo "     Your venv has been created in piper/src/python/.venv" >> $va
echo "     It must be activated manually from the command line." >> $va
echo " " >> $va
echo "     from this directory, run: " >> $va
echo " " >> $va
echo "              source piper/src/python/.venv/bin/activate" >> $va
echo

echo "$TEXTY_PATH" > "tts_dojo/.TEXTY_DIR"
echo "$TEXTY_PATH/piper/src/python/.venv/bin" > "tts_dojo/.BIN_DIR"
echo -e "${GREEN}Installation of Piper completed successfully.${RESET}"
echo

