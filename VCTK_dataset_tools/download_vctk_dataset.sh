#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if unzip is installed
if command_exists unzip; then
    echo "Unzip is installed."
else
    echo "Unzip is not installed."

    # Determine the operating system
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu-based systems
        echo "To install unzip, you can run the following command:"
        echo "sudo apt update && sudo apt install unzip"
    elif [[ -f /etc/redhat-release ]]; then
        # Red Hat/CentOS/Fedora-based systems
        echo "To install unzip, you can run the following command:"
        echo "sudo yum install unzip"
    elif [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        echo "To install unzip on macOS, use Homebrew:"
        echo "brew install unzip"
    else
        # Unknown system
        echo "Please consult your system's documentation to install unzip."
    fi
fi

# Expected file size for VCTK-Corpus-0.92.zip
EXPECTED_FILE_SIZE=11747302977

# Check if the zip file exists and has the correct size
if [[ -f "VCTK-Corpus-0.92.zip" && $(stat -c%s "VCTK-Corpus-0.92.zip") -eq $EXPECTED_FILE_SIZE ]]; then
    echo "VCTK-Corpus-0.92.zip is already downloaded."
else
    # Download VCTK dataset
    echo "About to download VCTK dataset. Warning! This is a very large file (~11GB)."

    # Ask user if they wish to proceed
    read -p "Do you want to proceed with the download? (y/n): " response
    response=${response,,}  # Convert to lowercase

    if [[ "$response" == "y" || "$response" == "yes" ]]; then
        echo "Starting download..."
        wget https://datashare.ed.ac.uk/bitstream/handle/10283/3443/VCTK-Corpus-0.92.zip
        echo "Download complete."
    else
        echo "Download aborted."
        exit 0
    fi
fi

# Ask if they want to unzip the downloaded file
echo
read -p "Corpus must be unzipped before use. Do you want to unzip now? (y/n): " response2
response2=${response2,,}  # Convert to lowercase

if [[ "$response2" == "y" || "$response2" == "yes" ]]; then
    if [[ -f "VCTK-Corpus-0.92.zip" ]]; then
        echo "Unzipping the corpus to VCTK-Corpus-0.92..."
        mkdir ./VCTK-Corpus-0.92
	unzip VCTK-Corpus-0.92.zip -d ./VCTK-Corpus-0.92
        echo "Unzipping complete."
    else
        echo "Error: VCTK-Corpus-0.92.zip was not found."
    fi
else
    echo "Exiting."
fi

