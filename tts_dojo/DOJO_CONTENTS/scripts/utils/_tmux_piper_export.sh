#!/bin/bash
# _tmux_piper_export.sh
# builds a complete piper voice with the help of textymcspeechy-piper Docker container
# this version updates the .onnx.json data to produce piper compliant models.


checkpoint="$1"  #a path to a ckpt file
destination="$2" #a path to an onnx file 
dojo_name="$3"   #eg test_dojo, used for building path inside the container.

DATASET_CONF_FILE="../target_voice_dataset/dataset.conf"
QUALITY_FILE="../target_voice_dataset/.QUALITY"
quality=""

if [[ -f $QUALITY_FILE ]]; then
    QUALITY_CODE=$(cat $QUALITY_FILE)
else
    echo "Error: .QUALITY file not found."
    exit 1
fi

# Load dataset.conf
if [ -e $DATASET_CONF_FILE ]; then
    source $DATASET_CONF_FILE
else
    echo "$0 - dataset.conf not found"
    echo "     expected location: $DATASET_CONF_FILE"
    echo 
    exit 1
fi
# Set PIPER_FILENAME_PREFIX from dataset.conf


if [ "$QUALITY_CODE" = "L" ]; then
    quality="low"
elif [ "$QUALITY_CODE" = "M" ]; then
    quality="medium"
elif [ "$QUALITY_CODE" = "H" ]; then
    quality="high" 
else 
    echo "Error - invalid value for quality: $QUALITY_CODE"
    exit 1
fi

SETTINGS_FILE="SETTINGS.txt"

if [ -e $SETTINGS_FILE ]; then
    source $SETTINGS_FILE
else
    echo "$0 - settings not found"
    echo "     expected location: $SETTINGS_FILE"
    echo 
    echo "press <enter> to exit"
    exit 1
fi

update_json() {
    local language_code="$1"
    local quality="$2"
    local filename="$3"

    # Extract the base name of the file (without extension)
    local dataset_name=$(basename "$filename" .onnx.json)

    # Use jq to update the JSON
    jq --arg lang_code "$language_code" \
       --arg quality_value "$quality" \
       --arg dataset "$dataset_name" \
       '.audio.quality = $quality_value |
        .language.code = $lang_code |
        .dataset = $dataset' \
       "$filename" > tmp.json && mv tmp.json "$filename" && chown 1000:1000 "$filename"
}


create_piper_voice(){
# convert .ckpt to .onnx voice model using textymcspeechy-piper docker container and copy .onnx.json to complete export

    # build absolute path to checkpoint file usable within textymcspeechy-piper docker container
    # example path: /app/tts_dojo/mydojo/voice_checkpoints/checkpoint_file.ckpt
    container_checkpoint=/app/tts_dojo/${dojo_name}/$(dirname "$checkpoint" | xargs basename)/$(basename "$checkpoint")
    
    # build absolute path to destination of new piper voice usable within textymcspeechy-piper docker container
    # example path:  /app/tts_dojo/voice_dojo/tts_voices/voice_3343/en_US-voice_3343-medium.onnx
    container_destination=/app/tts_dojo/${dojo_name}/tts_voices/$(dirname "$destination" | xargs basename)/$(basename "$destination")

    # run the export script on the docker container (only creates .onnx file from .ckpt)
    docker exec textymcspeechy-piper bash -c "cd /app/piper/src/python && python3 -m piper_train.export_onnx $container_checkpoint $container_destination" 
    
    # finish the export by copying .onnx.json file to destination folder on host
    cp ../training_folder/config.json "$destination.json"

    # update fields in json file so that they are what piper expects
    update_json "$PIPER_FILENAME_PREFIX" "$quality" "$destination.json"    

 }
 
# MAIN PROGRAM ****************************************************
echo "Checkpoint exporting to ONNX"
echo "checkpoint  = $checkpoint"
echo "destination = $destination"
echo "dojo_name   = $dojo_name"

# call the create_piper_voice function using time to track how long it takes to execute
time_output=$( (time create_piper_voice) 2>&1 )
echo "Done!"

# Extract the real time from the output
real_time=$(echo "$time_output" | grep real | awk '{print $2}')

# Convert the real time to seconds as an integer
minutes=$(echo "$real_time" | grep -oP '^\d+(?=m)')
seconds=$(echo "$real_time" | grep -oP '(?<=m)\d+(\.\d+)?s' | sed 's/s//')

# Handle cases where minutes might be empty
if [ -z "$minutes" ]; then
    minutes=0
fi

# Convert to total seconds
seconds_precise=$(echo "$minutes * 60 + $seconds" | bc)
seconds_int=$(printf "%.0f" "$seconds_precise")

# store to file path specified in SETTINGS.txt 
$(echo $seconds_int > $EXPORTER_LAST_EXPORT_SECONDS_FILE)
