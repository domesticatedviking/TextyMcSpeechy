#!/bin/bash
checkpoint="$1"  #a path to a ckpt file
destination="$2" #a path to an onnx file 
dojo_name="$3"  #eg test_dojo, used for building path inside the container.

#EXPORTER_LAST_EXPORT_SECONDS_FILE="/tmp/last_voice_export_seconds"


DOJO_DIR_FILE="../.DOJO_DIR"
if [ -e $DOJO_DIR_FILE ]; then
    DOJO_DIR=$(cat $DOJO_DIR_FILE)
else
    echo "Unable to find .DOJO_DIR.  Current path: $(pwd)  Exiting."
    exit 1
fi


settings_file="SETTINGS.txt"
if [ -e $settings_file ]; then
    source $settings_file
else
    echo "$0 - settings not found"
    echo "     expected location: $settings_file"
    echo 
    echo "press <enter> to exit"
    exit 1
fi




main(){
# call script in docker container

#echo "checkpoint:  $checkpoint path"
#echo "destination: $destination"
#echo "dojo_name:   $dojo_name"

#container_checkpoint=/app/tts_dojo/$dojo_name/$(basename "$checkpoint")
container_checkpoint=/app/tts_dojo/${dojo_name}/$(dirname "$checkpoint" | xargs basename)/$(basename "$checkpoint")
#container_destination=/app/tts_dojo/$dojo_name/$(basename "$destination")
container_destination=/app/tts_dojo/${dojo_name}/tts_voices/$(dirname "$destination" | xargs basename)/$(basename "$destination")
#echo "container_checkpoint: $container_checkpoint"
#echo "container_destination: $container_destination"
#echo "press Enter"
#read

docker exec textymcspeechy-piper bash -c "cd /app/piper/src/python && python3 -m piper_train.export_onnx $container_checkpoint $container_destination" 
cp ../training_folder/config.json "$destination.json"

 }
 

# Capture the output of the `time` command
#main
echo "Checkpoint exporting to ONNX"
time_output=$( (time main) 2>&1 )
echo "Done!"
##time_output=$( (time main) )

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

$(echo $seconds_int > $EXPORTER_LAST_EXPORT_SECONDS_FILE)

