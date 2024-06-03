#!/bin/bash

# Check if file path is provided as argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <file_path>"
    exit 1
fi

# Get the file extension
file_extension="${1##*.}"

# Check if file is WAV, FLAC, or MP3
if [ "$file_extension" != "wav" ] && [ "$file_extension" != "flac" ] && [ "$file_extension" != "mp3" ]; then
    echo "Unsupported file format. Only WAV, FLAC, and MP3 files are supported."
    exit 1
fi

# Check if the file exists
if [ ! -f "$1" ]; then
    echo "File $1 not found."
    exit 1
fi

# Get the sampling rate
sampling_rate=$(ffmpeg -i "$1" 2>&1 | grep -oE '[0-9]+ Hz' | head -n 1)

# Check if sampling rate is obtained
if [ -z "$sampling_rate" ]; then
    echo "Failed to retrieve sampling rate."
    exit 1
else
    echo "Sampling rate of $1 is: $sampling_rate"
fi

exit 0

