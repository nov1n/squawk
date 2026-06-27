# >>> squawk begin >>>
# Prerequisites for squawk's in-pane attention banner.
# https://github.com/nov1n/squawk
#
# IMPORTANT: source this LAST. Some themes (e.g. tokyo-night-tmux) turn
# pane-border-status off, so squawk must load after your plugin manager/theme
# to win. The banner swaps only pane-border-format, so keeping the status line
# always reserved (blank) avoids any resize/flicker.
set -g focus-events on
set -g pane-border-status top
set -g pane-border-format ''
# <<< squawk end <<<
