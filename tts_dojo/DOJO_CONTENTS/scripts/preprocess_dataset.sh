#!/bin/bash


# Exit immediately if any command returns a non-zero exit code
set +e
language=""
current_dir=$(pwd)



# Function to handle errors
error_handler() {
  echo "An error occurred in the script. Exiting."
  exit 1
}
export -f error_handler
# Trap errors and call the error_handler function
#trap 'error_handler' ERR SIGINT SIGTERM

BIN_DIR=$(cat .BIN_DIR)
#echo "BIN_DIR = '$BIN_DIR'"

PIPER_PATH=$(cat .PIPER_PATH)
#echo "PIPER_PATH = '$PIPER_PATH'"

DOJO_DIR=$(cat .DOJO_DIR)
#echo "DOJO_DIR = '$DOJO_DIR'"
cd $DOJO_DIR/scripts

TTS_DOJO_DIR=$(dirname $DOJO_DIR)  # parent of all dojos

#if [[ -n "$VIRTUAL_ENV" ]]; then
#    echo
#    
#elif [ -e "$BIN_DIR/activate" ]; then
#   echo "Activating virtual environment."
#   source $BIN_DIR/activate
#else
#    echo "ERROR --  No python virtual environment was found."
#    echo
#    echo "Exiting."
#    exit 1
#fi

SETTINGS_FILE="SETTINGS.txt"

if [ -e "$SETTINGS_FILE" ]; then 
    source "$SETTINGS_FILE"
else
    echo "could not find $SETTINGS_FILE.   exiting."
    exit 1
fi

MASTER_SETTINGS_FILE="$TTS_DOJO_DIR/DOJO_CONTENTS/scripts/$SETTINGS_FILE"

check_pretrained_language(){
   local pretrained=$(cat "$TTS_DOJO_DIR/PRETRAINED_CHECKPOINTS/default/.ESPEAK_LANGUAGE" 2>/dev/null || echo "")
   echo $pretrained
}





SAMPLING_RATE=$(cat .SAMPLING_RATE)      #inferred by dataset sanitizer
echo -e "       Auto-configured sampling rate: $SAMPLING_RATE"

MAX_WORKERS=$(cat .MAX_WORKERS)          #calculated by dataset sanitizer.
echo -e "    Calculated value for max-workers: $MAX_WORKERS"
echo
echo



pretrained_language=$(check_pretrained_language)
pretrained_absent=$?

SETTINGS_LANGUAGE=$SETTINGS_ESPEAK_LANGUAGE #eg, en-us

if [ "$pretrained_language" = "" ] && [ "$SETTINGS_LANGUAGE" != "" ]; then
    echo "Warning: No language was configured in PRETRAINED_CHECKPOINTS/DEFAULT/.ESPEAK_LANGUAGE"
    echo "Using value from SETTINGS.txt: $SETTINGS_LANGUAGE"
    language=$SETTINGS_LANGUAGE
    
elif [ "$pretrained_language" != "" ] && [ "$SETTINGS_LANGUAGE" = "" ]; then
    echo "Your pretrained checkpoint files are configured to use Espeak-ng language:  $pretrained_language"
    echo "However, no value for SETTINGS_ESPEAK_LANGUAGE is specified in scripts/$SETTINGS_FILE."
    echo
    echo "What would you like to do?"
    echo "[1] Make $pretrained_language the default language for this and all future dojos (recommended)"
    echo "[2] Make $pretrained_language the default language for this dojo only"
    echo "[3] Ask this again next time"
    
    read savelang
    if [ "$savelang" = "1" ]; then
        sed -i "s/^SETTINGS_ESPEAK_LANGUAGE=.*/SETTINGS_ESPEAK_LANGUAGE=$pretrained_language/" $MASTER_SETTINGS_FILE
    fi
    if [ "$savelang" = "1" ] || [ "$savelang" = "2" ]; then
        sed -i "s/^SETTINGS_ESPEAK_LANGUAGE=.*/SETTINGS_ESPEAK_LANGUAGE=$pretrained_language/" $SETTINGS_FILE
    fi
    language=$pretrained_language
    

elif [ "$pretrained_language" != "$SETTINGS_LANGUAGE" ] && [ "$SETTINGS_LANGUAGE" != "" ]; then
    echo "Warning: Default pretrained checkpoint files are not using the same language specified in $SETTINGS_FILE"
    echo -e "PRETRAINED_CHECKPOINTS/DEFAULT/.PRETRAINED_LANGUAGE contained:\n    $pretrained_language\n"
    echo -e "$(basename $DOJO_DIR)/scripts/SETTINGS.txt contained:\n    $SETTINGS_LANGUAGE\n"
    echo
    echo "What would you like to do?"
    echo "    [1] use $pretrained_language (the language of your pretrained TTS model)"
    echo "    [2] use $SETTINGS_LANGUAGE (the language in $SETTINGS_FILE)"
    echo "    [q] quit."
    echo -ne "     "
    read choice
    if [ $choice = "1" ]; then
        language=$pretrained_language
    elif [ $choice = "2" ]; then
        language=$SETTINGS_LANGUAGE
    else
        echo "exiting"
        exit 1
    fi
    
elif [ "$pretrained_language" = "" ] && [ "$SETTINGS_LANGUAGE" == "" ]; then
    echo "ERROR.  No value found for ESPEAK_LANGUAGE."  
    echo "edit $SETTINGS_FILE to set a default value for SETTINGS_ESPEAK_LANGUAGE"
    echo
    echo "exiting"
    exit 1
else
   language=$SETTINGS_LANGUAGE
fi

echo "Configuring piper for language: $language"
echo "Running piper_train.preprocess"
echo
echo

#extract the basename to build correct path for docker container
DOJO_NAME=$(basename $DOJO_DIR)
 
# Change to the appropriate directory
# Run the Python script
docker exec textymcspeechy-piper bash -c "
  cd /app/piper/src/python && \
  python3 -m piper_train.preprocess \
    --language ${language} \
    --input-dir \"/app/tts_dojo/${DOJO_NAME}/target_voice_dataset\" \
    --output-dir \"/app/tts_dojo/${DOJO_NAME}/training_folder\" \
    --dataset-format ljspeech \
    --single-speaker \
    --sample-rate ${SAMPLING_RATE} \
    --max-workers ${MAX_WORKERS}
"
result=$?
if [ $result -eq 0 ];then 
    echo
    echo
    echo
    echo "    Successfully preprocessed dataset."
    echo 
    echo "    Press <ENTER> to continue"
    read
    echo
else
    echo  "piper_train.preprocess failed.  Press <enter> to exit."
    read
    exit 1
fi
cd $DOJO_DIR/scripts
exit 0
