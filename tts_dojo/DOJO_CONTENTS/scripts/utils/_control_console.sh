#!/bin/bash
trap "kill 0" SIGINT
DOJO_DIR=$(cat ../.DOJO_DIR)
dojo_basename=$(basename $DOJO_DIR)
echo "Dojo located in $DOJO_DIR"
# Source the settings file
source SETTINGS.txt
source ../.colors
clear

# Initialize initial space and time
initial_space=$(df -BG --output=avail "$PWD" | tail -n 1 | tr -d 'G')
initial_time=$(date +%s)

# Function to get the available disk space in GB
space_remaining() {
    df -BG --output=avail "$PWD" | tail -n 1 | tr -d 'G'
}

# Function to calculate the total size of a directory in GB
dir_size_in_gb() {
    local dir_path="$1"
    if [ -d "$dir_path" ]; then
        local size_in_kb=$(du -sk "$dir_path" | cut -f1)
        local size_in_gb=$(echo "scale=2; $size_in_kb / 1024 / 1024" | bc)
        echo "$size_in_gb"
    else
        echo "Invalid directory"
    fi
}

# Function to calculate the amount of space being used per minute in GB
gb_per_minute() {
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

# Function to calculate the time until the drive will be full at the current usage rate
time_until_full() {
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
VOICE_TESTER_PANE="$TMUX_TESTER_PANE"

show_legend() {
    # Display legend of forwarded keys
    echo
    echo -e "${RED}WARNING: This program could fill your entire hard drive if you aren't paying attention.${RESET}"
    echo -e "${RED}         Every checkpoint file you save is over ${CYAN}800MB${RESET}."
    echo
    echo -e "Use ${CYAN}'tmux kill-session'${RESET} to shut all processes down from any terminal window"
    echo -e "To change to adjacent window without a mouse, use <CTRL> B followed by an arrow key."
    echo
    echo -e "To [q]uit training, select this pane and press [Q]."
    #echo " "

}

# Statistics updater
show_stats() {
    remaining=$(space_remaining)
    gb_min=$(gb_per_minute)
    time_full=$(time_until_full)
    dir_size=$(dir_size_in_gb $DOJO_DIR)
    
    clear
      #echo -e "${CYAN}${dojo_basename}${RESET} ${YELLOW}contains ${CYAN}${dir_size}${RESET}${YELLOW} GB of files.${RESET}"
    echo -e "${YELLOW}${GREEN}${remaining}${YELLOW} GB of storage remaining.  Using ${GREEN}${gb_min}${YELLOW} GB/min.    Approx time until full: ${GREEN}${time_full}${RESET}"


}

# Function to clean up on termination
cleanup() {
    echo "Terminating..."
    exit
}

# Set trap to catch termination signals and run cleanup
trap cleanup SIGINT SIGTERM

# Main loop
while true; do
    show_stats
    show_legend

    # Non-blocking read with a 1-second timeout
    if read -rsn1 -t 1 key; then
        case "$key" in
            [qQ]) kill_session ;;
            *) ;;
        esac
    fi
done

