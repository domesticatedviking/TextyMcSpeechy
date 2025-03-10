#!/bin/bash
# setup.sh setup script for TextyMcSpeechy dockerized piper build

RUN_CONTAINER_SCRIPT_NAME="run_container.sh"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m' # Reset text color to default

# Define an error handler
error_handler() {
  echo -e "${RED}An error occurred during the installation. Exiting.${RESET}"
}

# Set up the error trap to run the error handler on any error
trap error_handler ERR

informed_consent(){
# explains what script will do
    echo
    echo "This script will do the following things:"
    echo 
    echo "1. Install required packages"
    echo "    apt-get update"
    echo "    apt-get install tmux ffmpeg inotify-tools sox"
    echo
    echo "2. Make all .sh files in this project executable."
    echo "     eg. chmod +x *.sh"
    echo 
    echo "3. Let you choose which type of container you want to use with the tts dojo"
    echo "   (prebuilt image from dockerhub vs locally built docker image)"
    echo
    echo "4. Check whether Docker and NVIDIA Container Toolkit are installed"
    echo 
    echo "5. Check if nvidia-smi is installed and if yes, probe for available GPUs"
    echo 
    
}

script_run_container_boilerplate(){
# writes static part of run_container.sh
    tf=$RUN_CONTAINER_SCRIPT_NAME
    echo "#!/bin/bash" > $tf
    echo "# run_container.sh:  This script provides a single alias to one of the available ways of starting a docker container." >> $tf
    echo "#" >> $tf
    echo "# use one of the following options in this script:" >> $tf
    echo '# bash prebuilt_container_run.sh "$@" # launches prebuilt docker images which you downloaded' >> $tf
    echo '#    bash local_container_run.sh "$@" # launches images you built locally' >> $tf
    echo "" >> $tf
}

check_docker() {
# Check if Docker is installed by looking for the 'docker' command
    if command -v docker &> /dev/null; then
        echo "    OK! -- Docker is installed. "
        
    else
        echo "WARNING -- Required package Docker is not installed."
        echo "install instructions can be found here:"
        echo "https://docs.docker.com/engine/install/"
        echo
        
    fi
}


check_nvidia_container_toolkit() {
# Check if nvidia-container-toolkit is installed
    if dpkg -l | grep -q nvidia-container-toolkit; then
        echo "    OK! -- NVIDIA Container Toolkit is installed."
    else
        echo "WARNING! -- Required package NVIDIA Container Toolkit is not installed."
        echo "install instructions can be found here:"
        echo "https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
    fi
}

check_nvidia_gpus() {
    echo "Checking for NVIDIA GPUs..."
    if ! command -v nvidia-smi > /dev/null 2>&1; then
        echo "WARNING: nvidia-smi is not installed."
        echo "Without nvidia-smi, the system cannot automatically detect multiple GPU setups."
        echo "If you want to use a multi-GPU setup, please manually configure tts_dojo/scripts/.gpu."
    else
        GPU_COUNT=$(nvidia-smi -L | wc -l)
        echo "Detected $GPU_COUNT GPU(s):"
        nvidia-smi -L | sed 's/^GPU \([0-9]\+\):/[\1]/'
        if [ "$GPU_COUNT" -gt 1 ]; then
            echo "Multiple GPUs found. Note: Piper training supports only a single GPU at a time."
            echo "When launching newdojo.sh, you will be able to select which GPU to use."
        fi
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    informed_consent    
    echo
    echo
    echo "    Run this script again with sudo privileges to proceed"
    echo "             sudo bash setup.sh "
    echo
    exit 1
fi

clear
informed_consent
read -p "Do you wish to continue? (y/n): " response

if [[ "$response" =~ ^[Yy]$ ]]; then
    :
else
    echo "Exiting..."
    exit 1
fi


echo "Updating package index"
echo
apt-get update
echo
echo "Installing required packages"
echo
apt-get install tmux ffmpeg inotify-tools sox
echo
echo "Press <Enter> to continue"
read 
clear
echo 
echo "What kind of docker package do you want to use for textymcspeechy-piper?"
echo 
echo "     1.  I want to use a pre-built image from dockerhub. (recommended)"
echo "     2.  I want to use a local image that I will build myself."
echo
read -p "please choose 1 or 2: " response
if [[ "$response" == 1 ]]; then
    echo
    echo "configuring script: run_container.sh to run docker image using prebuilt_container_run.sh"
    echo "The prebuilt container will download the first time you run this script."
    echo 
    echo "The TTS dojo will automatically launch the docker image when you start training a model"
    script_run_container_boilerplate
    echo 'bash prebuilt_container_run.sh "$@"' >> $RUN_CONTAINER_SCRIPT_NAME
    echo "done."
    echo
elif [[ "$response" == 2 ]]; then
    echo "configuring script: run_container.sh to run a locally built docker image with local_container_run.sh"
    echo 
    echo "The TTS dojo will automatically launch the docker image when you start training a model"
    script_run_container_boilerplate
    echo 'bash local_container_run.sh "$@"' >> $RUN_CONTAINER_SCRIPT_NAME
    echo "done."
fi

echo 
echo  "Making all scripts executable"

chmod +x ./*.sh
chmod +x tts_dojo/*.sh
chmod +x tts_dojo/DOJO_CONTENTS/*.sh
chmod +x tts_dojo/DOJO_CONTENTS/scripts/*.sh
chmod +x tts_dojo/DOJO_CONTENTS/scripts/utils/*.sh
chmod +x tts_dojo/DATASETS/*.sh
chmod +x tts_dojo/PRETRAINED_CHECKPOINTS/*.sh
chmod +x tts_dojo/ESPEAK_RULES/*.sh
echo "done."

echo
echo "Checking for presence of required packages"
echo
check_docker
check_nvidia_container_toolkit
check_nvidia_gpus

# If everything went well, print the success message
echo
echo -e "${GREEN}All done.${RESET}"
echo
echo "  Please see quick_start_guide.md for instructions on how to train your first model" 
echo
