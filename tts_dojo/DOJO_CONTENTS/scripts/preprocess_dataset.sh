#!/bin/bash
#preprocess_dataset.sh:   Configures and runs piper_train.preprocess inside the textymcspeechy-piper docker container

DOJO_NAME=$(basename $PWD) # Get from <voice_name>_dojo
SETTINGS_FILE="SETTINGS.txt"
SAMPLING_RATE_FILE=".SAMPLING_RATE"
MAX_WORKERS_FILE=".MAX_WORKERS"
MASTER_SETTINGS_FILE="../../DOJO_CONTENTS/scripts/$SETTINGS_FILE" #relative to this dojo's scripts dir 

cd scripts # needed to ensure relative paths are built properly
set +e # Exit immediately if any command returns a non-zero exit code

#.SAMPLING_RATE and .MAX_WORKERS are stored in <voice>_dojo/scripts by link_dataset.sh
if [[ -f $SAMPLING_RATE_FILE ]]; then
    SAMPLING_RATE=$(cat $SAMPLING_RATE_FILE)
else
    echo "Error: .SAMPLING_RATE file not found."
    exit 1 
fi

if [[ -f $MAX_WORKERS_FILE ]]; then
    MAX_WORKERS=$(cat $MAX_WORKERS_FILE)
else
    echo "Error: .MAX_WORKERS file not found."
    exit 1
fi



language=""

# load settings
if [ -e "$SETTINGS_FILE" ]; then 
    source "$SETTINGS_FILE"  #loads vars from SETTINGS.txt
else
    echo "could not find $SETTINGS_FILE. Exiting."
    exit 1
fi


error_handler() {
  echo "An error occurred in the script. Exiting."
  exit 1
}

export -f error_handler

# Trap errors and call the error_handler function
trap 'error_handler' ERR SIGINT SIGTERM


check_pretrained_language(){
   local pretrained=$(cat "../../PRETRAINED_CHECKPOINTS/default/.ESPEAK_LANGUAGE" 2>/dev/null || echo "")
   echo $pretrained
}


# MAIN PROGRAM ********************************************************************************
      
echo -e "       Auto-configured sampling rate: $SAMPLING_RATE"         
echo -e "    Calculated value for max-workers: $MAX_WORKERS"
echo
echo

pretrained_language=$(check_pretrained_language)
pretrained_absent=$? 

SETTINGS_LANGUAGE=$SETTINGS_ESPEAK_LANGUAGE #eg en-us (sourced from SETTINGS.txt)

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
    echo -e "/scripts/SETTINGS.txt contained:\n    $SETTINGS_LANGUAGE\n"
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

echo "Configuring Piper for language: $language"
echo "Running piper_train.preprocess"
echo
echo

# Run the piper preprocessing script inside of the textymspeechy-piper docker container.
# note:  /app/piper/src/python refers to a path inside the container. 
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
    echo "    Successfully preprocessed dataset."
    echo 
    echo "    Press <Enter> to continue"
    read
    echo
else
    echo  "piper_train.preprocess failed.  Press <Enter> to exit."
    read
    exit 1
fi
exit 0
