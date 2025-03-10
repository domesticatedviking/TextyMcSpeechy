#!/bin/bash
# tts_dojo/ESPEAK_RULES/apply_custom_rules.sh
# this script runs run_in_container_as_root.sh on the textymcspeechy-piper docker container. 
#
# ESPEAK_RULES should contain all the pronunciation files for your chosen language from espeak-ng/dictsource (available on github)
# for English, the files you need are:  en_list, en_rules, en_emoji, en_extra
# you also need to create an en_extra file which contains your customized pronunciations.
#
# see https://github.com/domesticatedviking/TextyMcSpeechy/blob/docker-dev/docs/altering_pronunciation.md for instructions.
#

LANGUAGES=$1
LOGFILE="container_apply_custom_rules.log"

if [ -z "$LANGUAGES" ]; then
    echo 	
    echo "Usage:  apply_custom_rules.sh <language>
    echo "   eg:  apply_custom_rules.sh en   # english"
    echo
    echo "Please provide the language prefix for the rules you wish to activate."
    echo "  eg: for en_list, en_rules, en_emoji, and en_extra, the language prefix is en"
    echo
    echo "exiting"
    exit 1
fi

rm $LOGFILE # remove old logfile to avoid confusion
echo "Attempting to apply custom espeak-ng rules to textymcspeechy-piper docker container:"
echo
docker exec -u root -it textymcspeechy-piper bash /app/tts_dojo/ESPEAK_RULES/container_apply_custom_rules.sh "${LANGUAGES}" > $LOGFILE
result=$?
echo 
sleep 2

if [ -f $LOGFILE ]; then
  echo "Here is the output of $LOGFILE:"
  echo
  cat $LOGFILE
else
  echo "Error: apply_rules.log was not found."
  echo "It is likely the container script failed to execute."
  exit 1
fi

exit $result
