#!/bin/bash
checkpoint="$1"  #a ckpt file
destination="$2" #an onnx file 

#EXPORTER_LAST_EXPORT_SECONDS_FILE="/tmp/last_voice_export_seconds"


DOJO_DIR_FILE="../.DOJO_DIR"
if [ -e $DOJO_DIR_FILE ]; then
    DOJO_DIR=$(cat $DOJO_DIR_FILE)
else
    echo "Unable to find .DOJO_DIR.  Current path: $(pwd)  Exiting."
    exit 1
fi


PIPER_PATH_FILE="$DOJO_DIR/.PIPER_PATH"
if [ -e $PIPER_PATH_FILE ]; then
    PIPER_PATH=$(cat $PIPER_PATH_FILE)
else
    echo "Unable to find .PIPER_PATH. Current path: $(pwd) Exiting."
    exit 1
fi


#PIPER_PATH=$(cat .PIPER_PATH)




settings_file=$DOJO_DIR/scripts/SETTINGS.txt
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
cd $PIPER_PATH/src/python
python3 -m piper_train.export_onnx $checkpoint $destination 
cp $DOJO_DIR/training_folder/config.json "$destination.json"

 }
 

# Capture the output of the `time` command
time_output=$( (time main) 2>&1 )

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

