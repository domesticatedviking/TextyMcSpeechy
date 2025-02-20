#!/bin/bash
#preprocess_dataset.sh:   Configures and runs piper_train.preprocess inside the textymcspeechy-piper docker container

DOJO_NAME=$(basename $PWD) # Get from <voice_name>_dojo
SETTINGS_FILE="SETTINGS.txt"
SAMPLING_RATE_FILE=".SAMPLING_RATE"
MAX_WORKERS_FILE=".MAX_WORKERS"
MASTER_SETTINGS_FILE="../../DOJO_CONTENTS/scripts/$SETTINGS_FILE" #relative to this dojo's scripts dir
DATASET_CONF_FILE="../target_voice_dataset/dataset.conf" 

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

# load dataset.conf
if [ -e $DATASET_CONF_FILE ]; then
    source $DATASET_CONF_FILE
else
    echo "$0 - dataset.conf not found"
    echo "     expected location: $DATASET_CONF_FILE"
    echo 
    echo "press <enter> to exit"
    exit 1
fi

# Check whether the conf file is old and is missing values
missing=false
# Check if ESPEAK_LANGUAGE_IDENTIFIER is unset or empty
if [[ -z "$ESPEAK_LANGUAGE_IDENTIFIER" ]]; then
    echo
    echo
    echo "    Error: ESPEAK_LANGUAGE_IDENTIFIER is not set in dataset.conf."
    missing=true
fi

# Check if PIPER_FILENAME_PREFIX is unset or empty
if [[ -z "$PIPER_FILENAME_PREFIX" ]]; then
    echo "    Error: PIPER_FILENAME_PREFIX is not set in dataset.conf."
    echo
    missing=true
fi

# Exit if any variable was missing
if [[ "$missing" == true ]]; then
    echo
    echo "    Your dataset configuration file (dataset.conf) is outdated and needs to be updated."
    echo "        ESPEAK_LANGUAGE_IDENTIFIER must be set to the espeak-ng language identifier for the language of your dataset"
    echo "        eg: ESPEAK_LANGUAGE_IDENTIFIER=en-us"
    echo
    echo "    PIPER_FILENAME_PREFIX must be set to the language code Piper uses to name language files"
    echo "        eg: PIPER_FILENAME_PREFIX=en_US"
    echo
    echo "    either add these values to your dataset.conf file manually, or run:"
    echo
    echo "        DATASETS/create_dataset.sh <dataset_folder>"
    echo
    echo "    to rebuild the datasets.conf file."
    echo 
    echo "Exiting"
    exit 1
fi




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



# MAIN PROGRAM ********************************************************************************
      
echo -e "       Auto-configured sampling rate: $SAMPLING_RATE"         
echo -e "    Calculated value for max-workers: $MAX_WORKERS"
echo
echo


echo "Configuring Piper for language: ${ESPEAK_LANGUAGE_IDENTIFIER}"
echo "Running piper_train.preprocess"
echo
echo

# Run the piper preprocessing script inside of the textymspeechy-piper docker container.
# note:  /app/piper/src/python refers to a path inside the container. 
docker exec textymcspeechy-piper bash -c "
  cd /app/piper/src/python && \
  python3 -m piper_train.preprocess \
    --language ${ESPEAK_LANGUAGE_IDENTIFIER} \
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
