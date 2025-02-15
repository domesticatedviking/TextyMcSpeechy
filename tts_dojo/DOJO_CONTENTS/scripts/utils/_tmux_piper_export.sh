#!/bin/bash
# _tmux_piper_export.sh
# builds a complete piper voice with the help of textymcspeechy-piper Docker container

checkpoint="$1"  #a path to a ckpt file
destination="$2" #a path to an onnx file 
dojo_name="$3"   #eg test_dojo, used for building path inside the container.

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


create_piper_voice(){
# convert .ckpt to .onnx voice model using textymcspeechy-piper docker container and copy .onnx.json to complete export

    # build absolute path to checkpoint file usable within textymcspeechy-piper docker container
    # example path: /app/tts_dojo/mydojo/voice_checkpoints/checkpoint_file.ckpt
    container_checkpoint=/app/tts_dojo/${dojo_name}/$(dirname "$checkpoint" | xargs basename)/$(basename "$checkpoint")
    
    # build absolute path to destination of new piper voice usable within textymcspeechy-piper docker container
    # example path:  /app/tts_dojo/mydojo/tts_voices/mydojo_3343/mydojo_3343.onnx
    container_destination=/app/tts_dojo/${dojo_name}/tts_voices/$(dirname "$destination" | xargs basename)/$(basename "$destination")

    # run the export script on the docker container (only creates .onnx file from .ckpt)
    docker exec textymcspeechy-piper bash -c "cd /app/piper/src/python && python3 -m piper_train.export_onnx $container_checkpoint $container_destination" 
    
    # finish the export by copying .onnx.json file to destination folder on host
    cp ../training_folder/config.json "$destination.json"

 }
 
# MAIN PROGRAM ****************************************************
echo "Checkpoint exporting to ONNX"

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
