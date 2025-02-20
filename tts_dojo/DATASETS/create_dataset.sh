#!/bin/bash
# create_dataset.sh
# repackages a voice dataset into the format expected by TextyMcSpeechy
# how to use:
#    1. create a new folder inside of TextyMcSpeechy/tts_dojo/DATASETS/, eg my_dataset
#    2. copy your audio files and metadata.csv file into the my_datset folder. (keep backups elsewhere - this script will change the files)
#    3. from DATASETS, run create_dataset.sh my_dataset
#    4. your files will checked and organized by file type and sampling rate.
#    5. if WAV files in the sampling rates expected by Piper don't exist, this tool will create them.

set +e #exit on any error

# Pre-run safety checks
# Abort if run outside of DATASETS folder
DATASET_DIR=$(pwd)
if [[ ! "$DATASET_DIR" =~ DATASETS$ ]]; then
    echo "Error: for safety reasons this script only works within a directory called 'DATASETS'"
    exit 1
fi

input_dir="$1"
# Ensure input_dir is provided
if [ -z "$input_dir" ]; then
  echo -e "\n\nUsage: $0 <input_dir>   <input_dir> must contain audio files and a metadata.csv file\n\n"
  exit 1
fi

# Check if the directory exists before resolving the path
if [[ ! -d "$DATASET_DIR/$input_dir" ]]; then
    echo "Error: The specified directory '$input_dir' does not exist inside the DATASETS folder."
    echo "Exiting."
    exit 1
fi

# For additional safety, ensure that provided path is a real folder rather than a symlink
full_path=$(realpath "$DATASET_DIR/$input_dir" 2>/dev/null)
echo "$full_path"

# Ensure the resolved path is still inside DATASETS
if [[ "$full_path" != "$(realpath "$DATASET_DIR")/"* ]]; then
    echo "Error: Invalid directory. Path must be inside the DATASETS folder."
    echo "Exiting."
    exit 1
fi

# init global vars
not_audio_dir="$input_dir/not_audio"  
metadata_file="$input_dir/metadata.csv"
declare -A file_hashes
supported_formats=("flac" "wav" "m4a" "mp3")
total_files=0
processed_files=0
duplicate_files=0
moved_files=0
non_audio_files=0
highest_rate_folder=""
highest_rate=0
highest_rate_source_dir=""
espeak_lang=""  # stores espeak language identifier used by piper preprocessing to convert words to phonemes
piper_lang=""   # stores piper language code used by piper language naming specification


hash_file() {
# calculate SHA256 hash of a file
  local file="$1"
  sha256sum "$file" | awk '{ print $1 }'
}


check_delimiter() {
# Ensures CSV file uses the | character for delimiters
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "File does not exist."
        return 1
    fi
    
    local first_line
    first_line=$(head -n 1 "$file")
    
    if [[ "$first_line" == *'|'* ]]; then
        return 0
    else
        echo "ERROR.  Your metadata.csv file is not formatted using the | character as a delimiter between columns."
        echo "        Most spreadsheet programs can export csv files using user-specified delimiters."
        echo "        Please make this change and try again."
	echo 
        echo "Exiting."
        exit 1
        return 1
    fi
}


get_actual_format() {
# checks whether file extensions are lying about the contents of an audio file
  local file="$1"
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$file" 2>/dev/null
}


process_audio_file() {
# Processes a single audio file
  local file="$1"
  local extension="${file##*.}"
  local actual_format=$(get_actual_format "$file")

  if [ "$actual_format" != "$extension" ] && array_contains supported_formats "$actual_format"; then
    local new_file="${file%.*}.$actual_format"
    mv "$file" "$new_file" >/dev/null 2>&1
    file="$new_file"
    extension="$actual_format"
  fi

  local rate="$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$file" 2>/dev/null)"
  local target_dir="$input_dir/${extension}_${rate}"
  local target_file="$target_dir/$(basename "$file")"

  mkdir -p "$target_dir"

  local file_hash=$(hash_file "$file")
  if [ -n "${file_hashes[$file_hash]}" ]; then
    echo "Duplicate file detected and discarded: $file"
    rm "$file"
    duplicate_files=$((duplicate_files + 1))
  elif [ "$file" != "$target_file" ]; then
    file_hashes["$file_hash"]="$file"
    mv "$file" "$target_dir/" >/dev/null 2>&1
    moved_files=$((moved_files + 1))
  fi
}


process_non_audio_file() {
# Processes a single non-audio file
  local file="$1"
  local force="${2:-false}"
  if [ "$(basename "$file")" != "metadata.csv" ] || [ $force = "true" ]; then
    mv "$file" "$not_audio_dir/" >/dev/null 2>&1
    non_audio_files=$((non_audio_files + 1))
  fi
}


cleanup_empty_dirs() {
# removes any dirs that are empty after sorting
  find "$input_dir" -type d -empty -delete
}


array_contains() {
# finds a value in an array
  local array="$1[@]"
  local seeking=$2
  local in=1
  for element in "${!array}"; do
    if [[ "$element" == "$seeking" ]]; then
      in=0
      break
    fi
  done
  return $in
}


get_sampling_rate() {
# extract sampling rate from a directory name
    echo "$1" | awk -F'_' '{print $2}'
}


resample_convert() {
# resample and convert a folder full of audio files
    local source_folder="$1"
    local output_dir="$DATASET_DIR/$input_dir/"$2""  # Output directory based on argument (wav_16000 or wav_22050)
    #echo "****************************************************"
    #echo "RESAMPLE_CONVERT:   Got source_folder $source_folder"
    #echo "                    Got output_dir    $output_dir"
    #echo "****************************************************"

    #echo "Highest_rate_folder = $source_folder"
    # Check if output directory exists, create if not
    if [ ! -d "$output_dir" ]; then
        mkdir -p "$output_dir"
    fi

    # Loop through files in highest_rate_folder
    for file in "$source_folder"/*; do
        #echo "output_file=$file"
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            extension="${filename##*.}"  # Extract current extension
            new_filename="${filename%.*}.wav"  # Replace extension with .wav
            
            output_file="$output_dir/$new_filename"


            # Check if output file already exists, skip if so
            if [ ! -f "$output_file" ]; then
                # Determine target sample rate based on argument
                case "$2" in
                    wav_16000)
                        target_rate=16000
                        ;;
                    wav_22050)
                        target_rate=22050
                        ;;
                    *)
                        echo "Unsupported output directory: $2"
                        return 1
                        ;;
                esac               
                # Resample and convert using ffmpeg
                ffmpeg -i "$file" -ar "$target_rate" "$output_file" >/dev/null 2>&1
                
            else
                :
                # skip file
            fi
        fi
    done
}


process_files(){
# Iterate through all files in input_dir and subdirectories
    find "$DATASET_DIR"/"$input_dir" -type f | while read -r file; do
        processed_files=$((processed_files + 1))
        extension="${file##*.}"
        if array_contains supported_formats "$extension"; then
            process_audio_file "$file"
        elif [ "$file" != "$metadata_file" ]; then
            process_non_audio_file "$file"
        fi
        echo -ne "Processed $processed_files of $total_files files...\r"
   done
}


check_metadata(){
# Check for multiple metadata.csv files, compare their hashes and discard duplicates
    deletable_metadata_files=()
    # Find metadata files and store them in an array
    mapfile -t metadata_files < <(find "$input_dir" -name "metadata.csv" -print0 | tr '\0' '\n')

    if [ "${#metadata_files[@]}" -gt 1 ]; then
        echo -e "Multiple metadata.csv files found:"
        declare -A metadata_hashes
        for file in "${metadata_files[@]}"; do
            hash=$(hash_file "$file")
            echo -e "    $file\n      hash: $hash\n"
            if [ -n "${metadata_hashes[$hash]}" ]; then
                deletable_metadata_files+=("$file")
            else
                metadata_hashes["$hash"]="$file"
            fi
        done

        if [ "${#metadata_hashes[@]}" -gt 1 ]; then
            echo
            echo "WARNING.  Found multiple metadata.csv files with different contents."
            echo "          Please ensure only one dataset is in this folder."
            echo
            echo "Exiting."
            exit 1
        else
            for file in "${deletable_metadata_files[@]}"; do
                rm "$file"
            done
        fi
    fi
}

locate_highest_rate_folder() {
# determine which folder has files with highest sampling rate (use these for resampling)
    input_path="$DATASET_DIR"/"$input_dir"
    # Check if input directory is defined
    if [ -z "$input_dir" ]; then
        echo "Input directory not specified."
        exit 1
    else
        :
        # could log something here
    fi

    # Check if input directory exists
    if [ ! -d "$input_path" ]; then
        echo "Directory $input_dir does not exist."
        exit 1
    fi
    pattern="^($(IFS='|'; echo "${supported_formats[*]}"))_[0-9]+$"
    while IFS= read -r folder; do
        # Extract the basename of the folder
        folder_name=$(basename "$folder")
 
        # Ensure the folder name matches the pattern <audio file format>_<sampling_rate>
        if [[ "$folder_name" =~ $pattern ]]; then
            #echo "Found a sorted folder: $folder_name"
            # Extract sampling rate from folder name
            sampling_rate=$(echo "$folder_name" | awk -F'_' '{print $2}')
        
            # Ensure sampling_rate is a valid integer
            if [[ "$sampling_rate" =~ ^[0-9]+$ ]]; then
                # Compare sampling rates
                if (( sampling_rate > highest_rate )); then
                    highest_rate="$sampling_rate"
                    highest_rate_folder="$folder"
                fi
            else
                :
                # Invalid sampling rate
            fi
        else
            :
            # Folder does not match pattern
        fi
    done < <(find "$input_path" -type d -name '*_*')

    # Print the highest sampling rate folder
    if [ -n "$highest_rate_folder" ]; then
        echo "Highest sampling rate folder: $highest_rate_folder"
    else
        echo "No directories found matching the pattern '*_*' in $input_dir."
    fi
}


ensure_piper_sampling_rates(){
# ensure wav_16000 and wav_22050 exist
     if [ ! -z "$highest_rate_folder" ]; then
         echo -e "\nGenerating wav_16000 files\n"
         resample_convert "$highest_rate_folder" "wav_16000"
         echo -e "\nGenerating wav_22050 files\n"
         resample_convert "$highest_rate_folder" "wav_22050"
     else
         echo "Error - no highest rate folder was found."
     fi
}


verify_wav_files_against_metadata(){
# make sure files referenced in metadata.csv are present in directory
    local metadata=$1
    local wav_dir=$2
    local outcome="OK"
    
    # Read the metadata.csv file and process each line
    while IFS="|" read -r filename _; do
        # Append ".wav" to the filename
        local wav_file="${filename}.wav"

        # Check if the file exists in the specified directory
        if [[ ! -f "${wav_dir}/${wav_file}" ]]; then
            echo "MISSING FILE: ${wav_dir}/${wav_file}"
            outcome="FAIL"
        fi
    done < "$metadata"
    echo "Checked $(basename $wav_dir) for files in metadata.csv:  $outcome"
    echo
    echo

}

remove_blank_lines() {
# prevents errors in piper preprocessing by trimming blank lines from metadata.csv
    local csv_file="$1"
    # Use sed to remove blank lines from the end of the file
    sed -i '/^[[:space:]]*$/d' "$csv_file"
}


create_dataset_conf(){
# writes values to dataset.conf file
    local cf="$input_dir/dataset.conf"
    echo "# Texty McSpeechy Dataset Configuration" >$cf
    echo "NAME=\"$name\"" >> $cf
    echo "DESCRIPTION=\"$description\"" >> $cf
    echo "DEFAULT_VOICE_TYPE=\"$voicetype\"" >> $cf  
    echo "LOW_AUDIO=\"wav_16000\"" >> $cf  
    echo "MEDIUM_AUDIO=\"wav_22050\"" >> $cf  
    echo "HIGH_AUDIO=\"wav_22050\"" >> $cf
    echo "ESPEAK_LANGUAGE_IDENTIFIER=$espeak_lang" >> $cf
    echo "PIPER_FILENAME_PREFIX=$piper_lang" >> $cf
}

#!/bin/bash


convert_espeak_to_piper() {
# Convert espeak-ng language identifiers to format used by Piper language filenames
    local espeak_code="$1"

    # Define a mapping of espeak-ng codes to Piper language codes
    declare -A lang_map=(
        ["af"]="af"          # Afrikaans
        ["sq"]="sq"          # Albanian
        ["am"]="am"          # Amharic
        ["ar"]="ar"          # Arabic
        ["an"]="an"          # Aragonese
        ["hy"]="hy"          # Armenian (Eastern)
        ["hyw"]="hyw"        # Armenian (Western)
        ["as"]="as"          # Assamese
        ["az"]="az"          # Azerbaijani
        ["ba"]="ba"          # Bashkir
        ["cu"]="cu"          # Chuvash
        ["eu"]="eu"          # Basque
        ["be"]="be"          # Belarusian
        ["bn"]="bn"          # Bengali
        ["bpy"]="bpy"        # Bishnupriya Manipuri
        ["bs"]="bs"          # Bosnian
        ["bg"]="bg"          # Bulgarian
        ["my"]="my"          # Burmese
        ["ca"]="ca"          # Catalan
        ["chr"]="chr"        # Cherokee - Western/C.E.D.
        ["yue"]="zh_HK"      # Chinese - Cantonese (Hong Kong)
        ["hak"]="zh_HK"      # Chinese - Hakka
        ["haw"]="haw"        # Hawaiian
        ["cmn"]="zh_CN"      # Chinese - Mandarin
        ["hr"]="hr"          # Croatian
        ["cs"]="cs"          # Czech
        ["da"]="da"          # Danish
        ["nl"]="nl"          # Dutch
        ["en-us"]="en_US"    # English - American
        ["en"]="en_GB"       # English - British
        ["en-029"]="en"      # English - Caribbean (default to generic)
        ["en-gb-x-gbclan"]="en_GB"  # English - Lancastrian
        ["en-gb-x-rp"]="en_GB"      # English - Received Pronunciation
        ["en-gb-scotland"]="en_GB"  # English - Scottish
        ["en-gb-x-gbcwmd"]="en_GB"  # English - West Midlands
        ["eo"]="eo"          # Esperanto
        ["et"]="et"          # Estonian
        ["fa"]="fa"          # Persian
        ["fa-latn"]="fa"     # Persian (Latin transliteration)
        ["fi"]="fi"          # Finnish
        ["fr-be"]="fr_BE"    # French - Belgium
        ["fr"]="fr"          # French - France
        ["fr-ch"]="fr_CH"    # French - Switzerland
        ["ga"]="ga"          # Gaelic - Irish
        ["gd"]="gd"          # Gaelic - Scottish
        ["ka"]="ka"          # Georgian
        ["de"]="de"          # German
        ["grc"]="grc"        # Greek - Ancient
        ["el"]="el"          # Greek - Modern
        ["kl"]="kl"          # Greenlandic
        ["gn"]="gn"          # Guarani
        ["gu"]="gu"          # Gujarati
        ["ht"]="ht"          # Haitian Creole
        ["he"]="he"          # Hebrew
        ["hi"]="hi"          # Hindi
        ["hu"]="hu"          # Hungarian
        ["is"]="is"          # Icelandic
        ["id"]="id"          # Indonesian
        ["ia"]="ia"          # Interlingua
        ["io"]="io"          # Ido
        ["it"]="it"          # Italian
        ["ja"]="ja"          # Japanese
        ["kn"]="kn"          # Kannada
        ["kok"]="kok"        # Konkani
        ["ko"]="ko"          # Korean
        ["ku"]="ku"          # Kurdish
        ["kk"]="kk"          # Kazakh
        ["ky"]="ky"          # Kyrgyz
        ["la"]="la"          # Latin
        ["lb"]="lb"          # Luxembourgish
        ["ltg"]="ltg"        # Latgalian
        ["lv"]="lv"          # Latvian
        ["lfn"]="lfn"        # Lingua Franca Nova
        ["lt"]="lt"          # Lithuanian
        ["jbo"]="jbo"        # Lojban
        ["mi"]="mi"          # Māori
        ["mk"]="mk"          # Macedonian
        ["ms"]="ms"          # Malay
        ["ml"]="ml"          # Malayalam
        ["mt"]="mt"          # Maltese
        ["mr"]="mr"          # Marathi
        ["nci"]="nci"        # Nahuatl - Classical
        ["ne"]="ne"          # Nepali
        ["nb"]="nb"          # Norwegian Bokmål
        ["nog"]="nog"        # Nogai
        ["or"]="or"          # Oriya
        ["om"]="om"          # Oromo
        ["pap"]="pap"        # Papiamento
        ["py"]="py"          # Pyash
        ["pl"]="pl"          # Polish
        ["pt-br"]="pt_BR"    # Portuguese - Brazil
        ["qdb"]="qdb"        # Lang Belta
        ["qu"]="qu"          # Quechua
        ["quc"]="quc"        # K'iche'
        ["qya"]="qya"        # Quenya
        ["pt"]="pt_PT"       # Portuguese - Portugal
        ["pa"]="pa"          # Punjabi
        ["piqd"]="tlh"       # Klingon
        ["ro"]="ro"          # Romanian
        ["ru"]="ru"          # Russian
        ["ru-lv"]="ru"       # Russian - Latvia (fallback to Russian)
        ["uk"]="uk"          # Ukrainian
        ["sjn"]="sjn"        # Sindarin
        ["sr"]="sr"          # Serbian
        ["tn"]="tn"          # Setswana
        ["sd"]="sd"          # Sindhi
        ["shn"]="shn"        # Shan (Tai Yai)
        ["si"]="si"          # Sinhala
    )

    # Return Piper code or fallback to input if not found
    echo "${lang_map[$espeak_code]:-NOT_FOUND}"
}




# **************************************************************************************************************************************************
# MAIN PROGRAM START

clear
echo -e  "    TextyMcSpeechy Dataset creator"
echo -e
echo -e  "    This tool will perform the following operations on files in $input_dir:"
echo
echo -e  "    1. Scan $input_dir and its subdirectories for audio files"
echo -e  "    2. Verify that file extensions match the contents of the files"
echo -e  "    3. Move audio files into folders classified by file format and sampling rate"
echo -e  "    4. Move any non-audio files to 'not_audio' directory"
echo -e  "    5. Remove empty directories"
echo -e  "    6. Select the highest sampling rate you have provided and resample to wav_22050 and wav_16000 (The formats piper needs)"
echo -e  "    7. Remove duplicate files"
echo -e  "    8. Check that all files referenced in metadata.csv exist."
echo -e  "    9. Create dataset.conf file, which TextyMcSpeechy uses to configure your dojo."
echo
echo -e  "    This tool will make changes to the files in $input_dir that cannot be undone."
echo -e  "    It is HIGHLY RECOMMENDED that you keep a backup of your original dataset files."
echo -e 
echo -ne "    Do you wish to proceed?  (Y/N) "
read choice

if  [ $choice != "Y" ] && [  $choice != "y" ]; then
    echo "Exiting."
    exit 1
fi


choice=""
echo -e
echo -e "    Piper uses espeak-ng to convert words in your dataset into phonemes during preprocessing."
echo -e "    Espeak-ng requires a specific identifier (eg \"en-us\") to choose which phonemes to use for the languages it supports."
echo -e "    A list of these codes is available in espeak_language_identifiers.txt."
echo -e
echo -ne "    Would you like to view the list now? [y/n]:  "
read choice
if [[ $choice == "Y" || $choice == "y" ]]; then
    less ./espeak_language_identifiers.txt
fi
echo
echo -ne "    What is the espeak-ng identifier for the language used in this dataset? (to show the list again, use \"S\"): "



while [ -z "$espeak_lang" ]; do
    read espeak_lang
    espeak_lang=$(echo "$espeak_lang" | tr '[:upper:]' '[:lower:]') # Convert to lowercase

    if [ "$espeak_lang" = "s" ]; then
        less ./espeak_language_identifiers.txt
        echo
        echo -ne "    What is the espeak-ng identifier for the language used in this dataset? (to show the list again, use \"S\"): "
        espeak_lang="" # Reset input to loop again

    elif [ -z "$espeak_lang" ]; then
        echo -ne "    What is the espeak-ng identifier for the language used in this dataset? (to show the list again, use \"S\"): "

    else
        # Convert espeak identifier to piper code
        piper_lang=$(convert_espeak_to_piper "$espeak_lang")
        if [ "$piper_lang" == "NOT_FOUND" ]; then
            echo -e "\n    The espeak identifier you provided was not valid."
            echo -ne "    What is the espeak-ng identifier for the language used in this dataset? (to show the list again, use \"S\"): "
            espeak_lang="" # Reset input to loop again
            piper_lang=""
        else
            echo -e "\n          Espeak language identifier for this language is set to: $espeak_lang"
            echo -e "               Looked up code to build piper-compliant file name: $piper_lang"
            echo -e "These values will be saved to dataset.conf in your dataset folder.\n"
        fi
    fi
done


echo -ne "    What name would you like to give this dataset?  (required): "
name=""
while [ "$name" = "" ]; do
    read name
    if [ "$name" = "" ]; then
    echo -ne "    What name would you like to give this dataset?  (required): "
    fi   
done
echo -e "\n    Describe the contents of this dataset? (optional)\n"
echo -ne "     "
read description

echo -e  "\n    TextyMcSpeechy uses pretrained piper checkpoint files as the basis for the voices it creates."
echo -e  "    Which type of voice should be the default base voice for this dataset?"
echo -e 
echo -e  "        [M] traditionally masculine voice"
echo -e  "        [F] traditionally feminine voice"
echo -ne "         "
response=""
voicetype=""

while [ "$response" = "" ]; do
    read vt
    vt="${vt^^}" #convert to uppercase
    if [ "$vt" = "M" ] || [ "$vt" = "F" ]; then
        response="true"
        voicetype=$vt
    else
        echo -ne "    Please select M or F:  "
    fi
done
    
# If dataset.conf exists, remove it.
if [ -e "$input_dir/dataset.conf" ]; then
    echo "Removing old dataset.conf"
    rm "$input_dir/dataset.conf"
fi

# Create not_audio directory if it doesn't exist
mkdir -p "$not_audio_dir"

# Count total files
total_files=$(find "$input_dir" -type f | wc -l)

check_metadata
echo -e "\nClassifying and moving files\n"
process_files
echo -e "\nRemoving empty directories\n"
cleanup_empty_dirs
echo -e "\nFinding best available sampling rate\n"
locate_highest_rate_folder
echo -e "\nEnsuring wav_22050 and wav_16000 exist, please wait.\n"
ensure_piper_sampling_rates
check_delimiter "$input_dir/metadata.csv"
echo -e "\nVerifying that files in metadata.csv exist\n"
verify_wav_files_against_metadata "$input_dir/metadata.csv" "$input_dir/wav_16000"
verify_wav_files_against_metadata "$input_dir/metadata.csv" "$input_dir/wav_22050"
remove_blank_lines "$input_dir/metadata.csv"

echo -e "\ncreating dataset.conf"
create_dataset_conf

echo -e "Dataset successfully created."
