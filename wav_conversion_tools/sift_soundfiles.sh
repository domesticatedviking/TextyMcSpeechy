#!/bin/bash
'''

sift_soundfiles.sh
  - organize and clean a folder of random audio files
  - organize into folders by file extension and subfolders by sampling rate
  - optionally detect files named as the wrong file format and renames them 
  - especially useful for gathering voice datasets
  
The MIT License (MIT)
Copyright © 2024 Erik Bjorgan

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
'''



allowed_extensions=("wav" "mp3" "flac")

check_ffprobe() {
    # Check if ffprobe command exists
    if ! command -v ffprobe &> /dev/null; then
        echo "ffprobe is not installed on your system."

        # Check if user is on Debian/Ubuntu system
        if [ -f /etc/debian_version ]; then
            echo "You can install ffprobe using the following command:"
            echo "sudo apt-get install ffmpeg"
        # Check if user is on CentOS/RHEL system
        elif [ -f /etc/redhat-release ]; then
            echo "You can install ffprobe using the following command:"
            echo "sudo yum install ffmpeg"
        # Check if user is on Arch Linux system
        elif [ -f /etc/arch-release ]; then
            echo "You can install ffprobe using the following command:"
            echo "sudo pacman -S ffmpeg"
        # Check if user is on macOS system
        elif [ "$(uname)" == "Darwin" ]; then
            echo "You can install ffprobe using Homebrew. If you don't have Homebrew installed, you can install it from https://brew.sh/"
            echo "Once Homebrew is installed, you can install ffprobe using the following command:"
            echo "brew install ffmpeg"
        else
            echo "Please install ffprobe manually or using your package manager."
        fi
        exit 1

    else
        return 0
    fi
}

check_audio_file_type() {
    local checkfile="$1"

    format=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 -content_type "" "${checkfile}" 2>/dev/null)
        
    if [ -n "${format}" ]; then
        echo "${format}"
    else
        echo "unknown"
    fi
}


# Function to copy or move audio files to organized directory
copy_files() {
    local input_dir="$1"
    local output_dir="$2"
    local fix_case="$3"
    local move_files="$4"
    local fix_type="$5"
  
    
    # Loop through all files in the input directory
    for file in "$input_dir"/*; do
        actual_type=""
        # Check if file is a regular file
        if [ -f "$file" ]; then
            #get just the filename without the extension
            original_filename=$(basename "$file")
            filename_no_extension="${original_filename%.*}"
            echo
            echo "$original_filename:"

            # Get file extension and sampling rate
            file_extension="${file##*.}"

            # Check if file extension is in the allowed list (case insensitive)
            if [[ ! " ${allowed_extensions[@]} " =~ " ${file_extension,,} " ]]; then
                echo "    Skipping $original_filename - not a supported audio file."
                continue
            fi
           
            # Convert file extension to lowercase if fix_case option is specified
            if [ $fix_case -eq 1 ]; then
                destination_extension="${file_extension,,}"
            else
                destination_extension="$file_extension"
            fi
            # output directory should always use lowercase filenames
            media_type_lowercase="${file_extension,,}"
            
            # Optionally verify that file contains what it claims to contain.
            if [ $fix_type -eq 1 ]; then
                checkpath="$(pwd)/${input_dir}/${original_filename}"
                actual_type=$(check_audio_file_type "${checkpath}")
                if [ $actual_type = "unknown" ]; then
                    echo "    $file contents were not a known file type. Skipping it."
                    continue
                fi
                if [ $actual_type != $media_type_lowercase ]; then
                    echo
                    echo "   FILE EXTENSION DOES NOT MATCH CONTENTS"
                    echo "          File was labelled as:  $media_type_lowercase"
                    echo "   File contents identified as:  $actual_type" 
                    echo
                    misnamed_new_name=$filename_no_extension.$actual_type
                    echo " renaming output file to: $misnamed_new_name"
                    destination_extension=$actual_type
                    media_type_lowercase=$actual_type
                               
                fi
            fi
          

            # construct filename with proper case for destination file
            destination_name_fixed="${filename_no_extension}.${destination_extension}"
            
            sampling_rate=$(ffmpeg -i "$file" 2>&1 | grep -oE '[0-9]+ Hz' | head -n 1)
            #remove spaces from sampling rate
            sampling_rate_dir="${sampling_rate// /}"
            # Create directory if it doesn't exist
            mkdir -p "$output_dir/$media_type_lowercase/$sampling_rate_dir"
            # Build destination file name
            destination_file="$output_dir/$media_type_lowercase/$sampling_rate_dir/$destination_name_fixed"
            # Move or copy the file based on the option
            if [ "$move_files" -eq 1 ]; then
                mv "$file" "$destination_file"
                echo "    $file moved to $destination_file."
            else
                cp "$file" "$destination_file"
                echo "    $file copied to $destination_file."
            fi
        fi
    done
}


# Function to handle output directory existence
handle_output_dir() {
    local output_dir="$1"
    
    # Check if output directory exists
    if [ ! -d "$output_dir" ]; then
        mkdir -p "$output_dir"
    else
        # Ask the user for action
        read -p "Directory '${output_dir}' already exists. Do you wish to [o]verwrite existing files, [d]elete the output directory and start over, or [q]uit? " choice
        case "$choice" in
            o|O )
                echo "Existing files will be overwritten."
                ;;
            d|D )
                echo "Deleting output directory and starting over..."
                rm -rf "$output_dir"
                ;;
            q|Q )
                echo "Quitting..."
                exit 0
                ;;
            * )
                echo "Invalid choice. Quitting..."
                exit 1
                ;;
        esac
    fi
}

# Check if input directory is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_folder> [<output_folder>] [--fix_case] [--fix_type] [--move]"
    echo "Organizes audio files into a folder named <input_folder>_ORGANIZED if <output_folder> is not provided"
    echo "Files are grouped into subfolders first by audio file type and then by sampling rate"
    echo "Files are optionally tested to ensure their contents match their file extensions (requires ffprobe)"

    echo "[--fix_case] - changes the file extensions of all copied files to lowercase"
    echo "    [--move] - moves the files into the output directory instead of copying them"
    echo "[--fix_type] - detects audio files with wrong file extensions and renames them in output"
    echo 
    exit 1
fi

# Get input directory path
input_dir="$1"  # this argument is mandatory
shift  # Move past the input folder argument
if [ -z "$1" ] || [ "$1" = -* ]; then
    output_dir="${input_dir}_ORGANIZED"
else
    output_dir="$1"
    shift
fi

# Check if input directory exists
if [ ! -d "$input_dir" ]; then
    echo "Input directory not found."
    exit 1
fi


# Determine whether to fix case and move files based on command line options
fix_case=0
move_files=0
fix_type=0
while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
        --fix_case)
            fix_case=1
            ;;
        --move)
            move_files=1
            ;;
        --fix_type)
            fix_type=1
            ;;
        *)
            echo "Invalid option: $key"
            exit 1
            ;;
    esac
    shift
done

if [ $fix_type = 1 ]; then
   check_ffprobe
fi


handle_output_dir "$output_dir"

# Copy or move files to organized directory
copy_files "$input_dir" "$output_dir" "$fix_case" "$move_files" "$fix_type"

echo "Files organized successfully."

exit 0

