#!/bin/bash

DOJO_DIR=$(cat .DOJO_DIR)
source_dir=${1:-"$DOJO_DIR/tts_voices"}

TTS_VOICES="tts_voices"

trap "kill 0" SIGINT
trap 'resize_term' SIGWINCH

resize_term() {
  term_width=$(tput cols)
  term_height=$(tput lines)
  display_menu
}

# Global variables
TEST_TEXT=$(cat testphrase.txt)
text_to_say="$TEST_TEXT"
selected=0
selected_directory=""
max_dirname_length=0
label=""
new_voice_added=""

sort_order="descending"  # Default sort order

get_directories() {
  directories=()
  while IFS= read -r -d '' dir_with_timestamp; do
    dir_path=$(echo "$dir_with_timestamp" | cut -d ' ' -f 2-)
    directories+=("$dir_path")
    dir_basename=$(basename "$dir_path")
    dir_length=${#dir_basename}
    if [ $dir_length -gt $max_dirname_length ]; then
      max_dirname_length=$dir_length
    fi
  done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d -printf "%T@ %p\0" 2>/dev/null)
  
  sort_directories
}

sort_directories() {
  if [ "$sort_order" = "ascending" ]; then
    directories=($(for dir in "${directories[@]}"; do echo "$(stat -c %Y "$dir") $dir"; done | sort -n | cut -d ' ' -f 2-))
  else
    directories=($(for dir in "${directories[@]}"; do echo "$(stat -c %Y "$dir") $dir"; done | sort -nr | cut -d ' ' -f 2-))
  fi
}

update_selection(){
  old_count=${#directories[@]}
  get_directories
  new_count=${#directories[@]}
  count_diff=$((new_count - old_count))  #check if files added since last update


  
  # ensure that selected item stays the same
  if [ $count_diff -gt 0 ] && [ $old_count ne 0 ]; then
      if [ "$sort_order" = "descending" ]; then
          # descending sort order means dir index 0 contains the newest file
          # To keep selection constant, need to add to selection as list grows
          selected=$((selected + count_diff)) # 
          
          
      fi
        
       
      
  fi
  # make sure selected stays in range.
  if [ $selected -gt $new_count ]; then
      selected=$((new_count -1))
  fi
  
  if [ $selected  -lt 0 ]; then
      selected=0
  fi
}



 display_menu() {



  term_width=$(tput cols)
  term_height=$(tput lines)
  local label_length=${#label}
  local column_width=$((max_dirname_length + 4))
  local num_columns=$((term_width / column_width))
  local num_rows
  
  #check for new files since last update
  update_selection
  
  if [ $num_columns -le 0 ]; then
    num_columns=1
  fi
  
  num_rows=$(((${#directories[@]} + num_columns - 1) / num_columns))
  local truncated_text
  
  if [ ${#text_to_say} -gt $((term_width - 15)) ]; then
    truncated_text="${text_to_say:0:$((term_width - 18))}..."
  else
    truncated_text="$text_to_say"
  fi

  local buffer=""
  buffer+="\033[H\033[J"  # Clear screen and move cursor to top
  #buffer+="\nold count: ${old_count}    new count: ${new_count}"
  buffer+="\n  ←↑↓→ choose voice  [c]hange text  [s]ay text  [f]lip sort order  [q]uit\n\n"
  
  if [ ${#directories[@]} -eq 0 ]; then
  buffer+="  No voices available to preview. \n"
  fi
 
  for ((row=0; row<num_rows; row++)); do
    for ((col=0; col<num_columns; col++)); do
      index=$((row + col * num_rows))
      if [ $index -lt ${#directories[@]} ]; then
        if [ $index -eq $selected ]; then
          buffer+="\033[7m"  # Inverse video
        fi
        buffer+=$(printf "%-*s" $column_width "$(basename "${directories[$index]}")")
        buffer+="\033[0m"  # Reset video
      fi
    done
    buffer+="\n"
  done




  buffer+="\nText to say: \"$truncated_text\"\n"


  echo -e "$buffer"

}

say_text() {
  tput sgr0
  local voice_dir=${directories[$selected]}
  local model_onnx="$(basename "$voice_dir").onnx"
  local onnx_path=$voice_dir/$model_onnx
  $DOJO_DIR/scripts/tts.sh "$text_to_say" "$onnx_path" >/dev/null 2>&1 
  display_menu 
}

prompt_text_to_say() {
  tput sgr0
  clear
  read -p "Enter new text: " new_text
  text_to_say="$new_text"
  display_menu
}


previous_voice() {
  if [ $selected -gt 0 ]; then
    ((selected--))
    display_menu
  fi
}

next_voice() {
  if [ $selected -lt $((${#directories[@]} - 1)) ]; then
    ((selected++))
    display_menu
  fi
}

left_voice() {
  local column_width=$((max_dirname_length + 4))
  local num_columns=$((term_width / column_width))
  local num_rows

  if [ $num_columns -le 0 ]; then
    num_columns=1
  fi

  num_rows=$(((${#directories[@]} + num_columns - 1) / num_columns))
  if [ $selected -ge $num_rows ]; then
    selected=$((selected - num_rows))
    display_menu
  fi
}

right_voice() {
  local column_width=$((max_dirname_length + 4))
  local num_columns=$((term_width / column_width))
  local num_rows

  if [ $num_columns -le 0 ]; then
    num_columns=1
  fi

  num_rows=$(((${#directories[@]} + num_columns - 1) / num_columns))
  if [ $selected -lt $((${#directories[@]} - num_rows)) ]; then
    selected=$((selected + num_rows))
    display_menu
  fi
}

flip_sort_order() {
  if [ "$sort_order" = "ascending" ]; then
    sort_order="descending"
  else
    sort_order="ascending"
  fi
  display_menu
}

get_directories #initial run

while true; do
  if read -rsn1 -t 3 key; then
  case "$key" in
    $'\x1b')  # Handle escape sequences
      read -rsn1 -t 0.1 key
      if [[ "$key" == "[" ]]; then
        read -rsn1 -t 0.1 key
        case "$key" in
          "A")  # Up arrow
            previous_voice
            ;;
          "B")  # Down arrow
            next_voice
            ;;
          "D")  # Left arrow
            left_voice
            ;;
          "C")  # Right arrow
            right_voice
            ;;
        esac
      fi
      ;;
    "p")  # p key
      previous_voice
      ;;
    "n")  # n key
      next_voice
      ;;
    "c")  # c key
      prompt_text_to_say
      ;;
    "s")  # s key
      say_text
      ;;
    "f")  # f key
      flip_sort_order
      ;;
    "q")  # q key
      tput sgr0
      clear
      kill $(jobs -p)
      exit 0
      ;;
  esac
  fi

display_menu
done

trap 'tput sgr0; clear; kill $(jobs -p); exit 0' SIGINT

tput sgr0
clear
#echo "Selected directory: $selected_directory"

