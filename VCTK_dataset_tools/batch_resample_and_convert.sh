#!/bin/bash

# List of common sample rates
COMMON_SAMPLE_RATES=(16000 22050 32000 40000 44100 48000)

# Default output format is based on input format
DEFAULT_OUTPUT_FORMAT=""

# Ensure that the script receives at least three arguments
if [ "$#" -lt 3 ]; then
  echo
  echo "Usage: $0 <input_dir> <output_dir> <sampling_rate> [--output_format <flac|wav>]"
  echo
  exit 1
fi

# Read input arguments
INPUT_DIR="$1"
OUTPUT_DIR="$2"
TARGET_RATE="$3"

# Optional argument for output format
if [ "$#" -eq 5 ] && [ "$4" == "--output_format" ]; then
  OUTPUT_FORMAT="$5"
  if [[ "$OUTPUT_FORMAT" != "flac" && "$OUTPUT_FORMAT" != "wav" ]]; then
    echo "Error: Invalid output format '$OUTPUT_FORMAT'. Use 'flac' or 'wav'."
    exit 1
  fi
else
  OUTPUT_FORMAT=""
fi

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

# Get the list of non-hidden WAV and FLAC files in the input directory
input_files=($(find "$INPUT_DIR" -maxdepth 1 -type f \( -name '*.wav' -o -name '*.flac' \) -not -name '.*'))

# Count the total number of non-hidden WAV/FLAC files
total_files=${#input_files[@]}
echo
echo "Found $total_files audio files in '$INPUT_DIR' to be converted."

# Process each input file
file_count=0
for file in "${input_files[@]}"; do
  # Increment the file count
  file_count=$((file_count + 1))

  # Get the filename and extension
  filename=$(basename -- "$file")
  extension="${filename##*.}"

  # Determine the default output format based on the input file format
  if [[ -z "$OUTPUT_FORMAT" ]]; then
    OUTPUT_FORMAT="$extension"
  fi

  # Display a progress indicator with the filename
  echo "Processing file $file_count of $total_files: $filename"

  # Construct the output file path with the specified output format
  base_filename="${filename%.*}"
  output_file="$OUTPUT_DIR/$base_filename.$OUTPUT_FORMAT"

  # Convert the file to the specified sampling rate and output format
  if ! ffmpeg -i "$file" -ar "$TARGET_RATE" "$output_file" > /dev/null 2>&1; then
    echo "Error converting $filename"
  fi
done

echo
echo "Conversion complete. Your converted files were created in the '$OUTPUT_DIR' directory."

