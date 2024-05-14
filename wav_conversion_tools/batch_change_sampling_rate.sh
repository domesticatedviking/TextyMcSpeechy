#!/bin/bash

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

# Validate input directory
if [ ! -d "$INPUT_DIR" ]; then
  echo "Error: '$INPUT_DIR' is not a valid directory"
  exit 1
fi

# Validate output directory
mkdir -p "$OUTPUT_DIR"

# Verify if the provided sampling rate is commonly used
if ! [[ " ${COMMON_SAMPLE_RATES[@]} " =~ " ${TARGET_RATE} " ]]; then
  echo
  echo "Error: The sampling rate $TARGET_RATE is not commonly used. Please choose from: ${COMMON_SAMPLE_RATES[*]}"
  echo
  exit 1
fi

# Get the list of non-hidden WAV files in the input directory
wav_files=($(find "$INPUT_DIR" -maxdepth 1 -type f -name '*.wav' -not -name '.*'))

# Count the total number of non-hidden WAV files
total_files=${#wav_files[@]}
echo
echo "Found $total_files WAV files in '$INPUT_DIR' to be converted."

# Process each WAV file
file_count=0
for file in "${wav_files[@]}"; do
  # Increment the file count
  file_count=$((file_count + 1))

  # Get the filename
  filename=$(basename -- "$file")

  # Display a progress indicator with the filename
  echo "Processing file $file_count of $total_files: $filename"

  # Construct the output file path with the same name
  output_file="$OUTPUT_DIR/$filename"

  # Convert the file to the specified sampling rate, suppressing standard output
  if ! ffmpeg -i "$file" -ar "$TARGET_RATE" "$output_file" > /dev/null 2>&1; then
    echo "Error converting $filename"
  fi
done

echo
echo "Conversion complete. Your converted files were created in the '$OUTPUT_DIR' directory."


