#!/bin/sh

# Default values
SAMPLING_RATE=16000
DATASET_DIR=""

BASE_DIR=$(pwd)

KEEP_ORIGINAL=false
echo
echo
# Function to display the usage of the script
usage() {
  echo "Usage: $0 --dataset_dir <dataset_dir> [--sampling-rate <16000 or 22050>] [--keep-original]"
  exit 1
}

# Parse command line arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dataset_dir)
      DATASET_DIR="$2"
      shift 2
      ;;
    --sampling-rate)
      SAMPLING_RATE="$2"
      if [ "$SAMPLING_RATE" -ne 16000 ] && [ "$SAMPLING_RATE" -ne 22050 ]; then
        echo "Invalid sampling rate. Allowed values are 16000 and 22050."
	echo
	echo
        exit 1
      fi
      shift 2
      ;;
    --keep-original)
      KEEP_ORIGINAL=true

      shift
      ;;
    *)
      usage
      ;;
  esac
done

# Validate dataset directory
if [ -z "$DATASET_DIR" ]; then
  echo "Error: --dataset_dir is required."
  usage
fi

STRIPPED_DATASET_DIR="${DATASET_DIR#./}"


# Backup FLAC files before continuing
echo "backing up original files to flac directory"
cp -r $STRIPPED_DATASET_DIR/wav $STRIPPED_DATASET_DIR/flac
echo "press enter to continue"
read



# Check if ffmpeg is installed
if ! command -v ffmpeg > /dev/null; then
  echo "ffmpeg is not installed."
  echo "Please install ffmpeg and try again."
  echo
  echo
  exit 1
fi

# Convert FLAC to WAV with the specified sampling rate
cd "$DATASET_DIR/wav" || { echo "Directory $DATASET_DIR/wav not found."; exit 1; }

for file in *.flac; do
  output_file="${file%.flac}.wav"
  ffmpeg -i "$file" -ar "$SAMPLING_RATE" "$output_file"
  echo "Converted $file to $output_file with a sampling rate of $SAMPLING_RATE."
done

# delete flac files from WAV folder
echo "Removing original flac files from $DATASET_DIR/wav"
cd $BASE_DIR
cd $STRIPPED_DATASET_DIR/wav
rm *.flac


echo "Conversion completed."


