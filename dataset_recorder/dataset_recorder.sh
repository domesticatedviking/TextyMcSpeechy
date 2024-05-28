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
OUTPUT_DIR=wav  #default if using ./metadata.csv
output_dir=""
declare -a filenames=()
declare -a phrases=()
declare -a recorded=()
no_recording_index="0"

cleanup(){
  echo "cleaning up processes"
  stty echo
  sleep 1
  stop_arecord
  tput cnorm  # Restore cursor
  sleep 1
  exit 1  # Exit with non-zero status to indicate interruption
}

center_text() { 
    COLUMNS=$(tput cols)
    printf "%*s\n" $(( ( $(echo $* | wc -c ) + COLUMNS ) / 2 )) "$*"
}

justify_text() {
    local width=$1
    local text=$2

    COLUMNS=$(tput cols)
    
    # Pad the text to the specified width
    text=$(printf "%-${width}s" "$text")

    # Calculate the center position
    printf "%*s\n" $(( ( ${#text} + COLUMNS ) / 2 )) "$text"
}

check_files() {
        
    for ((i = 0; i < ${#filenames[@]}; i++)); do
        thisfile=false
        path="$output_dir/${filenames[i]}"
 
        if [[ -f "$path" ]]; then
 
            recorded[i]=true
            thisfile=true
        else
 
           recorded[i]=false
           thisfile=false
        fi
        if [ "$no_recording_index" = "0" ] && [ "$thisfile" = "false" ]; then 

            no_recording_index=$((i-1))
 
        fi
       
    done
}

# Variable to store original terminal settings
original_tty_settings=""

# Function to hide cursor and keypresses
hide_terminal_output() {
    tput civis  # Hide cursor
    stty -echo  # Disable echoing keypresses
}

# Function to restore cursor and keypresses
restore_terminal_output() {
    stty echo
    tput cnorm  # Restore cursor
}


#!/bin/bash

# Function to trim 100 milliseconds from both ends of a .wav file and overwrite the original
trim_wav() {
    local input_file="$1"

    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        echo "Error: File '$input_file' not found."
        return 1
    fi

    # Create a temporary file path
    temp_file="/tmp/trimmed.wav"

    # Get the duration in seconds
    duration=$(ffprobe -i "$input_file" -show_entries format=duration -v quiet -of csv="p=0")

    # Calculate the new duration (original duration minus 0.2 seconds)
    new_duration=$(awk "BEGIN {printf \"%.3f\", $duration - 0.1}")

    # Trim and save to temporary file
    ffmpeg -y -i "$input_file" -ss 00:00:00.050 -t "$new_duration" -c copy "$temp_file" >/dev/null 2>&1

    # Check if ffmpeg command was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to trim '$input_file'."
        return 1
    fi
    # remove original file
    rm $input_file 

    # Copy temporary file back to original location with original filename
    cp "$temp_file" "$input_file"

    # Clean up temporary file
    rm "$temp_file"
}






# Function to stop arecord if running
stop_arecord() {
    # Check if arecord process is running and stop it
    if [[ -n "$arecord_pid" ]]; then
        kill "$arecord_pid" >/dev/null 2>&1
    fi
}

# Function to load metadata.csv into arrays
load_metadata() {
    local csv_file=${1:-"metadata.csv"}
    local line_number=0

    # Read metadata.csv line by line
    while IFS='|' read -r col1 col2 _; do
        if [ -z "$col1" ] || [ -z "$col2" ]; then
            break
        fi
        ((line_number++))
        index=$((line_number - 1))

        # Create filename with .wav suffix
        filename="${col1}.wav"

        # Create phrase with line number and text
        phrase="${line_number}. ${col2}"

        #echo "$line_number: ${filename}   ${phrase}"
        filenames+=("$filename")
        phrases+=("$phrase")
        recorded+=false # initialize array to hold recorded status of each item.

    done < "$csv_file"
}

# Function to output contents of filenames array
output_recorded() {
    echo "Recorded array:"
    printf '%s\n' "${recorded[@]}"
}

# Function to output contents of filenames array
output_filenames() {
    echo "Filenames array:"
    printf '%s\n' "${filenames[@]}"
}

# Function to output contents of phrases array
output_phrases() {
    echo "Phrases array:"
    printf '%s\n' "${phrases[@]}"
}


get_phrase(){
    local phrase=${phrases[$index]}
    echo "$phrase"
}

get_filename(){
    local filename=${filenames[$index]}
    echo "$filename"
}

# Function to handle Enter key press (for 'record_wav') using arecord
record_wav() {
    local filename=$(get_filename)
    update_display "Recording - press [r] to stop."
   

    # Start recording in the background with arecord
    arecord -f cd -t wav -d 30 -r 44100 "$output_dir"/"$filename" > /dev/null 2>&1 &
    arecord_pid=$!

    # Wait for 'r' or 'R' keypress to stop recording
    while true; do
        read -r -n 1 keypress

        if [[ "$keypress" == [rR] ]]; then
            stop_arecord
            recorded[index]=true
            trim_wav "$output_dir"/"$filename" "100"

            
            break
        fi
    done


}

listen_to_wav() {
    local filename=$(get_filename)
    aplay "$output_dir/$filename" >/dev/null 2>&1
    
}

show_item(){
    local phrase="$(get_phrase $index)"
    center_text "$phrase"
    
}

old_show_legend(){
   local builder=""
   local has_audio=${recorded[index]}
   if [ "$index" -ge "0" ]; then 
       builder+="[r]ecord\n"
   fi
   if [ "$index" -gt "0" ] ; then
       builder+="[p]revious\n"
   fi

   if [ "$has_audio" = "true" ]; then
       builder+="[n]ext\n"
       builder+="[l]isten to saved\n"
   fi
   builder+="[q]uit"
   
   echo -e $builder
   
 
}

show_legend(){
   echo -e "${YELLOW}"
   local has_audio=${recorded[index]}
   if [ "$index" -lt $((arraylength)) ]; then
       if [ "$index" -ge "0" ]; then 
               justify_text 20 "[r]ecord"
       fi
       if [ "$index" -gt "0" ] ; then
               justify_text 20 "[p]revious"
       fi
    
       if [ "$has_audio" = "true" ]; then
               justify_text 20 "[n]ext"
               justify_text 20 "[l]isten to saved"
       fi
       justify_text 20 "[q]uit"
       echo -e "${RESET}"
  else
        center_text "End of dataset."
        echo
        echo
        
       justify_text 20 "[q]uit"
       justify_text 20 "[p]revious"
       justify_text 20 "[g]o to start"
  fi
   
   
 
}



old_update_display(){
    legendinput = "$1":-""
    echo "legendinput = $legendinput"
    local legendline="${legendinput:-""}"
    clear
    echo -e  "\n\n\n\n\n\n\n\n\n\n"

    show_item
    echo -e  "\n\n\n\n"
    if [ "$legendline" = "" ]; then
        show_legend
    else
        justify_text 20 $legendline
    fi
}


update_display() {
    legendinput="$1"  # Enclose variable assignment in quotes to handle spaces correctly
    echo "legendinput = $legendinput"
    clear
    echo -e "\n\n\n\n\n\n\n\n\n\n"

    show_item
    echo -e "\n\n\n\n"
    if [ -z "$legendinput" ]; then  # Check if $legendinput is empty or not set
        show_legend
    else
        justify_text 20 "$legendinput"  # Pass $legendinput as a parameter to justify_text
    fi
}




# Main script logic
trap cleanup SIGINT SIGTERM
csv_file="${1:-metadata.csv}"
output_dir="${2:-$OUTPUT_DIR}"

load_metadata $csv_file
check_files
index=0
#output_recorded
clear
echo -e "\n\n\n\n\n\n\n"
center_text "Texty Mcspeechy speedy dataset recorder"
echo
center_text "Painlessly record a dataset for any 'metadata.csv' file"

if [ -n $1 ]; then
    center_text "Recording dataset for your csv file : $1"
else
    center_text "optional usage: ./dataset_recorder.sh [<your_metadata.csv>]  [<directory for recordings>]"
fi
echo
echo
center_text "press <ENTER>"
read
update_needed=true
if [ $no_recording_index -gt 0 ]; then
    clear
    echo -e "\n\n\n\n\n"
    center_text "Files from a previous session exist in directory \"$output_dir\""
    echo
    center_text "Would you like to:"
    justify_text 20 "  [D]elete files and start over"
    justify_text 20 "  [C]ontinue where you left off"
    read choice
    if [ $choice = "d" ] || [ $choice = "D" ]; then
        rm "$output_dir/*.wav"
        $no_recording_index=0
        index=$no_recording_index
    elif [ $choice = "c" ] || [ $choice = "C" ]; then
        echo "Continuing."
        index=$no_recording_index
    fi     
else
    index=0
fi
hide_terminal_output

arraylength=${#filenames[@]}

#update_display

while true; do
if [ "$update_needed" = "true" ]; then
    
    update_display

    update_needed=false
    fi
    read -r -n 1 keypress

    case "$keypress" in
        r|R)
            #don't allow recording when out of dataset
            if [ $index -lt $((arraylength )) ]; then 
                record_wav $index
                index=$((index + 1))
                update_needed=true
            fi
            ;;
        p|P)
            if [ $index -ge 1 ]; then
            index=$((index -1))
            update_needed=true
            fi
            ;;
        l|L)
            listen_to_wav
            ;;
        n|N)
            has_audio=${recorded[index]}
            echo 
            if [ $index -lt $arraylength ]  && [ "$has_audio" = "true" ]; then
                index=$((index +1))
                update_needed=true
            fi
            ;;
        q|Q)
            restore_terminal_output  # Ensure terminal settings are restored on exit
            exit 0
            ;;
        *)
            :  # do nothing
            ;;
    esac
    
        
done

