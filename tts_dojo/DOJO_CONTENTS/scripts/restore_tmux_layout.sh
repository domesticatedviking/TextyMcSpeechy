#!/bin/bash
# restore_tmux_layout.sh - restores tmux layout from file

SESSION="${1}"
LAYOUT_FILE="${2:-.tmux_layout}"

while IFS=: read -r index layout; do
  layout=$(echo "$layout" | sed 's/^ *//')  # Trim leading spaces

  tmux select-window -t "${SESSION}:${index}"

  # Ensure the correct number of panes exist before applying layout
  panes_required=$(echo "$layout" | grep -o '[0-9]\+x[0-9]\+,[0-9]\+,[0-9]\+,[0-9]\+' | wc -l)
  panes_current=$(tmux list-panes -t "$SESSION" | wc -l)

  if [[ $panes_current -lt $panes_required ]]; then
    echo "Creating additional panes to match layout..."
    for ((i=panes_current; i<panes_required; i++)); do
      tmux split-window -h -t "$SESSION"
    done
    tmux select-layout -t "$SESSION" tiled
  fi

  tmux select-layout -t "$SESSION" "$layout"
done < "${LAYOUT_FILE}"
