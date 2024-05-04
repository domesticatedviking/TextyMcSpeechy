#!/bin/bash

# Changes the sampling rate of a directory full of audio files with specified input and output formats

# List of common sample rates
COMMON_SAMPLE_RATES=(16000 22050 32000 40000 44100 48000)

# List of acceptable formats for input and output
ACCEPTABLE_FORMATS=("wav" "flac")

# Ensure that the script receives at least three arguments
if [ "$#" -lt 3 ]; then
  echo
  echo "Usage: $0 <input_dir> <output_dir> <sampling_rate> [--input_format <format>] [--output_format <format>]"
  echo
  exit 1
fi

# Read input arguments
INPUT_DIR="$1"
OUTPUT_DIR="$2"
TARGET_RATE="$3"

# Default input and output formats
INPUT_FORMAT="wav"
OUTPUT_FORMAT="wav"

# Parse additional arguments for input and output format
shift 3
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --input_format)
      INPUT_FORMAT="$2"
      if ! [[ " ${ACCEPTABLE_FORMATS[@]} " =~ " ${INPUT_FORMAT} " ]]; then
        echo
        echo "Error: The input format '$INPUT_FORMAT' is not supported. Supported formats are: ${ACCEPTABLE_FORMATS[*]}"
        echo
        exit 1
      fi
      shift 2
      ;;
    --output_format)
      OUTPUT_FORMAT="$2"
      if ! [[ " ${ACCEPTABLE_FORMATS[@]} " =~ " ${OUTPUT_FORMAT} " ]]; then
        echo
        echo "Error: The output format '$OUTPUT_FORMAT' is not supported. Supported formats are: ${ACCEPTABLE_FORMATS[*]}"
        echo
        exit 1
      fi
      shift 2
      ;;
    *)
      echo
      echo "Error: Unrecognized argument '$1'."
      echo
      exit 1
      ;;
  esac
done

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

# Get the list of non-hidden audio files in the input directory with the specified format
audio_files=$(find "$INPUT_DIR" -maxdepth 1 -type f -name "*.${INPUT_FORMAT}" -not -name '.*')

# Count the total number of non-hidden audio files
total_files=$(echo "$audio_files" | wc -l)
echo
echo "Found $total_files '${INPUT_FORMAT}' files in '$INPUT_DIR' to be converted."

# Process each audio file
file_count=0
while IFS= read -r file; do
  # Increment the file count
  file_count=$((file_count + 1))

  # Get the filename
  filename=$(basename -- "$file")
  
  # Remove the original extension
  base_filename="${filename%.*}"

  # Display a progress indicator with the filename
  echo "Processing file $file_count of $total_files: $filename"

  # Construct the output file path with the specified format
  output_file="$OUTPUT_DIR/${base_filename}.${OUTPUT_FORMAT}"

  # Convert the file to the specified sampling rate and output format, suppressing standard output
  ffmpeg -i "$file" -ar "$TARGET_RATE" "$output_file" > /dev/null 2>&1
done <<< "$audio_files"

echo
echo "Conversion complete. Your converted files were created in the '$OUTPUT_DIR' directory with the '${OUTPUT_FORMAT}' format."

