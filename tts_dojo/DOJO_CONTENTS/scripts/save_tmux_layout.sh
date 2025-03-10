#!/bin/bash
# save_tmux_layout.sh - saves the current tmux layout to file

SESSION="${1}"
LAYOUT_FILE="${2:-.tmux_layout}"

tmux list-windows -t "$SESSION" -F '#{window_index}: #{window_layout}' > "${LAYOUT_FILE}"
