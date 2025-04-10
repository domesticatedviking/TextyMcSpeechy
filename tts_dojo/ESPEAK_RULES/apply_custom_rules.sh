#!/bin/bash
# tts_dojo/ESPEAK_RULES/apply_custom_rules.sh
# this script runs run_in_container_as_root.sh on the textymcspeechy-piper docker container.
#
# ESPEAK_RULES should contain all the pronunciation files for your chosen language
# from espeak-ng/dictsource (available on github). For English, the files you need are:
#  en_list, en_rules, en_emoji, en_extra
# You also need to create an en_extra file which contains your customized pronunciations.
#
# see https://github.com/domesticatedviking/TextyMcSpeechy/blob/docker-dev/docs/altering_pronunciation.md for instructions.

LANGUAGES="$1"
CONTAINER_NAME="$2"

if [ -z "$LANGUAGES" ] || [ -z "$CONTAINER_NAME" ]; then
    echo        
    echo "Usage:  apply_custom_rules.sh <language> <container_name> [logfile]"
    echo "   eg:  apply_custom_rules.sh en textymcspeechy-piper   # english"
    echo
    echo "Please provide the language prefix for the rules you wish to activate and the target container name."
    echo "  eg: for en_list, en_rules, en_emoji, and en_extra, the language prefix is en"
    echo
    echo "exiting"
    exit 1
fi

if [ -n "$3" ]; then
    LOGFILE="$3"
else
    LOGFILE="container_apply_custom_rules-${CONTAINER_NAME}.log"
fi

rm -f "$LOGFILE" 2>/dev/null

echo "Attempting to apply custom espeak-ng rules to ${CONTAINER_NAME} docker container:"
echo
docker exec -u root -it "$CONTAINER_NAME" bash /app/tts_dojo/ESPEAK_RULES/container_apply_custom_rules.sh "${LANGUAGES}" > "$LOGFILE"
result=$?
echo 
sleep 2

if [ -f "$LOGFILE" ]; then
  echo "Here is the output of $LOGFILE:"
  echo
  cat "$LOGFILE"
else
  echo "Error: $LOGFILE was not found."
  echo "It is likely the container script failed to execute."
  exit 1
fi

exit $result
