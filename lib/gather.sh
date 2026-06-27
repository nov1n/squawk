# shellcheck shell=bash
# Gather environment facts (macOS frontmost app, tmux pane state). Side-effecting
# reads — stubbed in tests.

# get_frontmost -> bundle id of the frontmost application ("" on error)
get_frontmost() {
  osascript -e \
    'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' \
    2>/dev/null
}

# get_pane_stats <pane> -> "<pane_active> <window_active> <session_attached>"
get_pane_stats() {
  tmux display-message -p -t "$1" \
    '#{pane_active} #{window_active} #{session_attached}' 2>/dev/null
}
