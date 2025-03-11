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
# docker exec -u root -it textymcspeechy-piper "/app/tts_dojo/ESPEAK_RULES/container_apply_custom_rules.sh en > apply_rules.log"  

LANGUAGES=$1  # this will be a string.  Multiple languages can be separated with spaces (eg. "en ru it de")
LOGFILE=$2

# Path where espeak-ng rules are globally built when they compile
GLOBAL_RULE_PATH="/usr/lib/x86_64-linux-gnu/espeak-ng-data"
# piper phonemizer has its own espeak-ng-data folder in the venv   
PIPER_PHONEMIZE_RULE_PATH="/app/piper/src/python/.venv/lib/python3.10/site-packages/piper_phonemize/espeak-ng-data"

PIPER_PHONEMIZE_SYMLINK_TARGET=$(dirname "$PIPER_PHONEMIZE_RULE_PATH")

problem_count=0

# Convert the string into an array using a delimiter and assign to language_array
IFS=' ' read -r -a language_array <<< "$LANGUAGES"


show_launch_command(){
echo "docker exec -u root -it textymcspeechy-piper \"/app/tts_dojo/ESPEAK_RULES/container_apply_custom_rules.sh <language prefix> > $LOGFILE\""
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

if [ -z "$LANGUAGES" ]; then
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
    local prefix=$1  # The prefix parameter
    echo "Checking for presence of required files"
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
        echo "Error: Some required files are missing for language: $prefix."
        echo "       These rules will not be applied."
        (( problem_count++))
        return 1
    else
        echo "All required espeak-ng rules files are present for language: $prefix"
        return 0
    fi
}


cd $ESPEAK_RULES_DIR
echo "This script was run on: $(date '+%Y-%m-%d %H:%M:%S') UTC"
echo "language(s) requested by user:  $LANGUAGES"
echo "Compiling rules for espeak-ng.  These rules will be in effect until the container is restarted."

# Loop through the array and print each element
for lang in "${language_array[@]}"; do
  echo
  echo "Processing language rules for: $lang"
  check_files $lang
  if [ $? -eq 0 ]; then
      # show custom rules being applied in log file
      if [ -f "${lang}_extra" ]; then

          echo "The following custom pronunciation rules will be applied from ${lang}_extra:"
          cat "${lang}_extra"
      fi
      espeak-ng --compile=$lang  # only runs if no files were missing
      compile_result=$?
      (( problem_count += compile_result ))  # count nonzero exit codes for espeak as problems
      if [ $compile_result -eq 0 ]; then
          echo "Compiled dictionary entry ${lang}_dict. File will be copied to piper_phonemize ruleset in Piper venv."
          echo " copying : $GLOBAL_RULE_PATH/${lang}_dict"
          echo "      to : $PIPER_PHONEMIZE_RULE_PATH"
          cp "$GLOBAL_RULE_PATH"/"${lang}_dict" "$PIPER_PHONEMIZE_RULE_PATH"
          echo
          echo
      fi
      
  fi  
done

if [ $problem_count -eq 0 ]; then
  echo "Successfully compiled espeak-ng rules for: $LANGUAGES." 
  exit 0
else
  echo "Warning: There were problems compiling espeak-ng rules."
  exit $problem_count
fi

exit 0
