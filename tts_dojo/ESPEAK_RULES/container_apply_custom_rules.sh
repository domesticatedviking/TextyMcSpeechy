#!/bin/bash
# tts_dojo/ESPEAK_RULES/container_apply_custom_rules.sh
# activates custom pronunciation rules inside the textymcspeechy-piper container (requires root)
#
# ESPEAK_RULES should contain all the pronunciation files for your chosen language from espeak-ng/dictsource (available on github)
# for English, the files you need are:  en_list, en_rules, en_emoji, en_extra
# you also need to create an en_extra file which contains your customized pronunciations.
#
# see https://github.com/domesticatedviking/TextyMcSpeechy/blob/docker-dev/docs/altering_pronunciation.md for instructions.
#
# this script requires root access to the docker container
# call it with the command below (substitute appropriate language for "en")
# docker exec -u root -it textymcspeechy-piper "/app/tts_dojo/ESPEAK_RULES/apply_custom_rules.sh en > apply_rules.log"  

LANGUAGE=$1 
LOGFILE="container_apply_custom_rules.log"

show_launch_command(){
echo "docker exec -u root -it textymcspeechy-piper \"/app/tts_dojo/ESPEAK_RULES/container_apply_custom_rules.sh <language prefix> $LOGFILE\""
echo "eg:    docker exec -u root -it textymcspeechy-piper \"/app/tts_dojo/ESPEAK_RULES/container_apply_custom_rules.sh en > $LOGFILE\""
}

ESPEAK_RULES_DIR="/app/tts_dojo/ESPEAK_RULES"  # this is a path inside the docker container
echo "************************************************"
echo "      container_apply_custom_rules.sh"
echo "************************************************"
echo

if [ ! -d "$ESPEAK_RULES_DIR" ]; then
    echo
    echo "Directory $ESPEAK_RULES_DIR does not exist."
    echo "This is likely because you are trying to run this script on the host computer."
    echo "This script is intended to run as root, inside the textymcspeechy-piper docker container."
    echo "to run it manually, first bring the docker container up, then run:"
    show_launch_command
     
    echo
    echo "Exiting."
    echo
    echo
    exit 1
fi

if [ -z "$LANGUAGE" ]; then
    echo "Error: You must provide the language code as the first parameter to $0."
    echo "It should be the same code used in the prefix for the custom rules"
    echo "  eg: for en_list, the language code is en"
    echo "exiting"
    exit 1
fi


if [ "$(id -u)" -ne 0 ]; then    
    echo "ERROR: This script must be run in the textymcspeechy-piper docker container with root privileges "
    echo "Run it from the host with:"
    show_launch_command
    echo
    exit 1
fi

check_files() {
    local prefix="$LANGUAGE"  # The prefix parameter
    if [ -z "$prefix" ]; then
        echo "Error: No language code provided."
        exit 1
    fi

    # Define an array with the file suffixes you want to check
    local suffixes=("list" "rules" "emoji" "extra")
    local missing_files=()

    # Loop through each suffix and check if the corresponding file exists
    for suffix in "${suffixes[@]}"; do
        local filename="${prefix}_${suffix}"
        if [ ! -f "$filename" ]; then
            missing_files+=("$filename")
            echo "Warning: required file '$filename' is missing."
        fi
    done

    # If there are missing files, exit with error
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo "Error: Some required files are missing."
        exit 1
    fi

    echo "All required espeak-ng rules files are present. (language=$LANGUAGE)"
}


cd $ESPEAK_RULES_DIR
echo "This script was run on: $(date '+%Y-%m-%d %H:%M:%S') UTC"
check_files
echo "Compiling rules for espeak-ng.  These will be applied to all future voice models"
espeak-ng --compile=$LANGUAGE
if [ $? -eq 0 ]; then
  echo "Successfully compiled espeak-ng rules."
else
  echo "Compiling espeak-ng rules failed. (exit code=$?)."
fi
exit 0
