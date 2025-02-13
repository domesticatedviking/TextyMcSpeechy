#!/bin/bash

# Default output filename
output_file="output_audio.wav"

if [ -e ".DOJO_DIR" ]; then   # running from voicename_dojo
    DOJO_DIR=$(cat ".DOJO_DIR")
else
    echo ".DOJO_DIR not found.   Exiting"
    exit 1
fi

DOJO_NAME=$(basename $DOJO_DIR)

echo "SayTTS.sh"
echo
echo "params received:"
echo "$1"
echo "$2"
echo "$3"



# Check for text argument
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 'text to say' [--filename <filename>] [/path/to/model.onnx]"
  exit 1
fi

# Parse arguments
text=""
onnx_path=""
filename_provided=0

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --filename)
      if [ -n "$2" ]; then
        output_file="$2"
        shift
        filename_provided=1
      else
        echo "Error: --filename flag provided but no filename specified."
        exit 1
      fi
      ;;
    *)
      if [ -z "$text" ]; then
        text="$1"
      elif [ -z "$onnx_path" ]; then
        onnx_path="$1"
      fi
      ;;
  esac
  shift
done

# If ONNX file path is not provided, find one in the current directory
if [ -z "$onnx_path" ]; then
  onnx_files=($(ls *.onnx 2>/dev/null))
  if [ "${#onnx_files[@]}" -eq 0 ]; then
    echo "No ONNX file provided and no ONNX file found in the current directory."
    exit 1
  else
    onnx_path="${onnx_files[0]}"
    echo "Using ONNX file: $onnx_path"
  fi
fi


# Generate the audio file with Piper in the docker container
docker exec -it textymcspeechy-piper bash -c "cd /app/tts_dojo/${DOJO_NAME}/scripts && \
echo \"$text\" | piper -m \"$onnx_path\" --output_file \"$output_file\""

# Inform the user and attempt to play the audio file
echo "Audio generated and saved to $output_file"

# Attempt to play the audio file with aplay
if command -v aplay &> /dev/null; then
  aplay "$output_file"
else
  echo "aplay command not found. Cannot play the audio."
fi

