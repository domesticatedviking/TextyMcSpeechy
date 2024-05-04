#!/bin/bash

# Changes the sampling rate of a directory full of wav files

# List of common sample rates
COMMON_SAMPLE_RATES=(16000 22050 32000 40000 44100 48000)

# Ensure that the script receives exactly three arguments
if [ "$#" -ne 3 ]; then
  echo
  echo "Usage: $0 <input_dir> <output_dir> <sampling_rate>"
  echo
  exit 1
fi

# Read input arguments
INPUT_DIR="$1"
OUTPUT_DIR="$2"
TARGET_RATE="$3"

# Check if INPUT_DIR and OUTPUT_DIR are the same
if [ "$INPUT_DIR" = "$OUTPUT_DIR" ]; then
  echo
  echo "Error: The input directory and output directory must not be the same."
  echo
  exit 1
fi

# Verify if the provided sampling rate is commonly used
if ! [[ " ${COMMON_SAMPLE_RATES[@]} " =~ " ${TARGET_RATE} " ]]; then
  echo
  echo "Error: The sampling rate $TARGET_RATE is not commonly used. Please choose from: ${COMMON_SAMPLE_RATES[*]}"
  echo
  exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get the list of non-hidden WAV files in the input directory
wav_files=$(find "$INPUT_DIR" -maxdepth 1 -type f -name '*.wav' -not -name '.*')

# Count the total number of non-hidden WAV files
total_files=$(echo "$wav_files" | wc -l)
echo
echo "Found $total_files WAV files in '$INPUT_DIR' to be converted."

# Process each WAV file
file_count=0
while IFS= read -r file; do
  # Increment the file count
  file_count=$((file_count + 1))

  # Get the filename
  filename=$(basename -- "$file")

  # Display a progress indicator with the filename
  echo "Processing file $file_count of $total_files: $filename"

  # Construct the output file path with the same name
  output_file="$OUTPUT_DIR/$filename"

  # Convert the file to the specified sampling rate, suppressing standard output
  ffmpeg -i "$file" -ar "$TARGET_RATE" "$output_file" > /dev/null 2>&1
done <<< "$wav_files"

echo
echo "Conversion complete. Your converted files were created in the '$OUTPUT_DIR' directory."

