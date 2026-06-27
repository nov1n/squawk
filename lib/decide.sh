# shellcheck shell=bash
# Pure decision logic: given visibility facts, choose the reaction.
# No external commands — trivially unit-testable.

# decide <terminal_frontmost> <in_tmux> <session_attached> <window_active> <pane_active>
#   args are "1"/"0" (session_attached may be a raw tmux count).
# Echoes exactly one of: NOTHING | BANNER | NOTIFY
decide() {
  local frontmost="$1" in_tmux="$2" attached="$3" window_active="$4" pane_active="$5"

  # Not focused on the terminal, or not inside tmux: we can't reason about the
  # pane being on-screen, so notify.
  if [ "$frontmost" != "1" ] || [ "$in_tmux" != "1" ]; then
    echo NOTIFY
    return
  fi

  # Terminal is frontmost and we're in tmux. The pane is on-screen only if its
  # session has a client attached and its window is the active one.
  if [ "${attached:-0}" != "0" ] && [ "$window_active" = "1" ]; then
    if [ "$pane_active" = "1" ]; then
      echo NOTHING # you're looking right at it
    else
      echo BANNER # visible but not the focused pane
    fi
    return
  fi

  # Attached elsewhere: another window or a detached/background session.
  echo NOTIFY
}

# permission_decision <choice> -> the PermissionRequest hook's stdout JSON.
# Only an explicit "Approve" allows; "Deny" denies; anything else (a different
# action, a timeout, a dismiss, empty) prints nothing -> Claude falls back to the
# normal interactive permission prompt. This is the safety boundary: ambiguity
# never auto-approves.
permission_decision() {
  case "$1" in
    Approve) printf '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}' ;;
    Deny) printf '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}' ;;
    *) : ;;
  esac
}

# reply_decision <text> -> a Stop-hook decision that blocks the stop and feeds
# <text> back so Claude continues with it. Empty text prints nothing -> Claude
# stops normally. Built with jq so the reply is safely escaped. The empty guard
# also keeps a stray/timeout reply from looping the conversation.
reply_decision() {
  [ -n "$1" ] || return 0
  jq -nc --arg r "$1" '{decision: "block", reason: $r}'
}
