#!/bin/bash
# ANSI COLORS
RESET='\033[0m' # Reset text color to default
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
clear
echo -e "   ${CYAN}Training is now underway.${RESET}"
echo -e "   Raw output of Piper training appears in the top pane."
echo -e "   ${YELLOW}You can ignore any warning about the dataloader not having enough workers${RESET}"
echo 
echo -e "   When training is initializing, a line that says 'rank_zero_warn(' may appear ${PURPLE}*for several minutes*${RESET}"
echo -e "   However, after that you will begin to see lines that look like this:"
echo
echo -e "${YELLOW}DEBUG:fsspec.local:open file: ... your_dojo/training_folder/lightning_logs/version_0/checkpoints/${GREEN}epoch=2190-step=1366512.ckpt${RESET}"
echo 
echo -e "   The number after ${GREEN}'epoch='${RESET} will start to go up as your model is training "
echo 
echo -e "   The middle pane is running a tensorboard server which allows you to view"
echo -e "   your model's training progress in your web browser"
echo -e "   You will find it at ${CYAN}http://localhost:6006${RESET}. "
echo -e " "
echo -e "   ${RED}YOU ARE RESPONSIBLE FOR DECIDING WHEN TO STOP TRAINING - THIS WON'T FINISH ON ITS OWN${RESET}"
echo -e "   Generally, it takes between 100-1000 epochs to fine-tune an existing text-to-speech model"
echo
echo -e "   ${PURPLE}To stop training, press <ENTER>${RESET}"
read
echo -e "   ${RED}Press <ENTER> again to confirm that you are ready to stop training this model.{$RESET}"
read
tmux kill-session



