#!/bin/bash
# save_tmux_layout.sh - saves the current tmux layout to file

LAYOUT_FILE="${1:-.tmux_layout}"

tmux list-windows -F '#{window_index}: #{window_layout}' > "${LAYOUT_FILE}"  
