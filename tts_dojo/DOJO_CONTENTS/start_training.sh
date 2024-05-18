#!/bin/bash

RESET='\033[0m' # Reset text color to default
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD_BLACK='\033[1;30m'
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'
BOLD_PURPLE='\033[1;35m'
BOLD_CYAN='\033[1;36m'
BOLD_WHITE='\033[1;37m'

this_dir=$(pwd)
dir_only=$(basename "$this_dir")
echo "This dir =  $this_dir"
if [ $dir_only = "$DOJO_CONTENTS" ]; then
   echo -e "${RED}The DOJO_CONTENTS folder is used as a template for other dojos."
   echo -e "You should not run any scripts inside of DOJO_CONTENTS"
   echo 
   echo -e "Instead, run 'newdojo.sh' <voice name> to create a new dojo"
   echo -e "and train your models in that folder." 
   echo
   echo -e "Exiting${RESET}"
   exit 1
fi



# Exit immediately if any command returns a nonzero exit code
set -e


# Function to check the return code of the last executed command
check_exit_status() {
    if [ $? -ne 0 ]; then
        echo "${RED}An error occurred. start_training.sh is stopping.${RESET}"
        exit 1
    fi
}
clear
echo -e "      ${BOLD_PURPLE}TextyMcspeechy TTS_Dojo - Training Script${RESET}"

echo -e "      The dataset in target_voice_dataset will be analyzed and cleaned before training."
echo -e "      it is ${BOLD_YELLOW}highly recommended ${RESET}that you do not put the only copy of your files into this"
echo -e "      alpha version of a script written by an amateur whom you haven't met."
echo -e ""
echo -e "      Use at your own risk, obviously.   That's what I would do."
echo -e "      Do you want to proceed?"
read -p "      (y/n): " choice

# Check the user's response
if [[ "$choice" != [Yy]* ]]; then
    echo "     I understand completely."
    exit 1
fi


echo "      Let's get that dataset sanitized and analyzed for you."
echo "      running .scripts/0_sanitize_dataset.sh"
sleep 2
clear

bash ./scripts/0_sanitize_dataset.sh
check_exit_status

clear
echo "     Well I hope that worked because we are ready to begin pre processing."
echo "     running ./scripts/1_preprocess.sh"
echo

# Execute the preprocessing script
bash ./scripts/1_preprocess.sh
check_exit_status  # Check if the last command failed
echo
echo
echo "     That didn't take very long compared to this next one."
echo "     Because you don't want to know how much linear algebra we have to do now."
echo ""
echo "     It's weird that we're going to be training an AI, but we are."
echo "     To do that we're going to do a couple of things at once, "
echo "     So we're going to split the screen into three panes" 
echo 
echo "     Be sure to read the instructions on the bottom pane when it appears"
echo "     Especially the part where it tells you have to manually quit"
echo "     ... or you'll be here forever. "

echo
read -p " Are we doing this?  (y/n): " choice

# Check the user's response
if [[ "$choice" != [Nn]* ]] || ["$choice" == ""]; then
    echo "    Awesome.  Now running ./scripts/2_training.sh"
    bash ./scripts/2_training.sh
    check_exit_status  # Check if training script failed
else
    echo "    You do you.  No hard feelings."
    exit 3
fi
clear
echo "      Are you ready to take all of that sweet math and turn it into a voice which"
echo "      you promise to use for things which are fun, honourable, and legal?"
read -p "      (y/n): " choice

# Check the user's response
if [[ "$choice" == [Yy]* ]]; then
    echo "Alright. Running./scripts/3_finish_voice.sh"
    bash ./scripts/3_finish_voice.sh
    check_exit_status  # Check if training script failed
else
    echo "Good talking to you.  We should do this again."
    exit 3
fi



echo "start_training.sh: All training scripts completed"
echo
echo
exit 0




