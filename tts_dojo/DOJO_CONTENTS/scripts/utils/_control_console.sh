#!/bin/bash
# _control_console.sh - Provides stats on hard drive usage and controls for shutting down the training environment

trap "kill 0" SIGINT

DOJO_DIR=$(basename "$(dirname "$PWD")")  # this script runs from <name>_dojo/scripts so need parent directory   
VOICE_NAME=$(echo "$DOJO_DIR" | sed 's/_dojo$//')
SETTINGS_FILE="SETTINGS.txt"
COLOR_FILE=".colors"

# load settings
if [ -e $SETTINGS_FILE ]; then
    source $SETTINGS_FILE
else
    echo "$0 - settings not found"
    echo "     expected location: $SETTINGS_FILE"
    echo 
    echo "press <Enter> to exit"
    exit 1
fi

# load color file
if [ -e $COLOR_FILE ]; then
    source $COLOR_FILE
else
    echo "$0 - COLOR_FILE not found"
    echo "     expected location: $settings_file"
    echo 
    echo "exiting"
    exit 1
fi

clear

# Initialize initial storage space remaining and time
initial_space=$(df -BG --output=avail "$PWD" | tail -n 1 | tr -d 'G')
initial_time=$(date +%s)


space_remaining() {
# get the available disk space in GB
    df -BG --output=avail "$PWD" | tail -n 1 | tr -d 'G'
}


dir_size_in_gb() {
# calculate the total size of a directory in GB
    local dir_path="$1"
    if [ -d "$dir_path" ]; then
        local size_in_kb=$(du -sk "$dir_path" | cut -f1)
        local size_in_gb=$(echo "scale=2; $size_in_kb / 1024 / 1024" | bc)
        echo "$size_in_gb"
    else
        echo "Invalid directory"
    fi
}


gb_per_minute() {
# calculate the amount of space being used per minute in GB
    local current_space=$(space_remaining)
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - initial_time))
    
    if (( elapsed_time == 0 )); then
        echo "0.00"
        return
    fi

    local space_used=$(echo "scale=2; ($initial_space - $current_space)" | bc)
    local rate_per_second=$(echo "scale=2; $space_used / $elapsed_time" | bc)
    local rate_per_minute=$(echo "scale=2; $rate_per_second * 60" | bc)

    # Update initial state for the next call
    initial_space=$current_space
    initial_time=$current_time

    echo "$rate_per_minute"
}


time_until_full() {
# calculate the time until the drive will be full at the current usage rate
    local remaining_space=$(space_remaining)
    local usage_rate=$(gb_per_minute)
    if (( $(echo "$usage_rate == 0" | bc -l) )); then
        echo "..."
    else
        local time_in_minutes=$(echo "scale=0; $remaining_space / $usage_rate" | bc)
        local hours=$((time_in_minutes / 60))
        local minutes=$((time_in_minutes % 60))
        printf "%02dh %02dm\n" "$hours" "$minutes"
    fi
}

kill_session() {
    tmux kill-session
}

# Define the target pane to send keys to
VOICE_TESTER_PANE="$TMUX_TESTER_PANE"  # specified in SETTINGS.txt

show_legend() {
# Display legend of forwarded keys
    echo -e "${RED}WARNING: This program could fill your entire hard drive if you aren't paying attention.${RESET}"
    echo -e "${RED}         Every checkpoint file you save is over ${CYAN}800MB${RESET}."
    echo
    echo -e "Use ${CYAN}'tmux kill-session'${RESET} to shut all processes down from any terminal window"
    echo -e "To change to adjacent window without a mouse, use <CTRL> B followed by an arrow key."
    echo -e "save [t]mux layout, [r]estore tmux layout"
    echo
    echo -e "To [q]uit training, select this pane and press [Q]."
}

# Statistics updater
show_stats() {
    remaining=$(space_remaining)
    gb_min=$(gb_per_minute)
    time_full=$(time_until_full)
    dir_size=$(dir_size_in_gb $DOJO_DIR)      
    echo -e "${YELLOW}${GREEN}${remaining}${YELLOW} GB of storage remaining.  Using ${GREEN}${gb_min}${YELLOW} GB/min.    Approx time until full: ${GREEN}${time_full}${RESET}"

}

save_tmux_layout(){
# save the current arrangement of tmux window panes
    bash save_tmux_layout.sh
}

restore_tmux_layout(){
# restores a previous layout of tmux window panes from .tmux_layout file
    bash restore_tmux_layout.sh
}


# Function to clean up on termination
cleanup() {
    echo "Terminating..."
    exit
}

# Set trap to catch termination signals and run cleanup
trap cleanup SIGINT SIGTERM

# Check if .tmux_layout exists
if [ -f ".tmux_layout" ]; then
    restore_tmux_layout
fi


# Main loop
last_refresh_time=0
refresh_interval=60  # how many seconds to wait between refresh

while true; do
    current_time=$(date +%s)
    
    # Refresh only once every minute
    if ((current_time - last_refresh_time >= refresh_interval)); then
        clear
        show_stats
        show_legend
        last_refresh_time=$current_time
    fi

    # Non-blocking read with a 1-second timeout
    if read -rsn1 -t 1 key; then
        case "$key" in
            [qQ]) kill_session ;;
            [rR]) restore_tmux_layout ;;
            [tT]) save_tmux_layout ;;
            *) ;;
        esac
fi
done
