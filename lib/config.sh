# shellcheck shell=bash
# Configuration: environment defaults and terminal resolution.

# Optional user config file (sets any SQUAWK_* vars). Sourced if present.
if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/squawk/config" ]; then
  # shellcheck source=/dev/null
  . "${XDG_CONFIG_HOME:-$HOME/.config}/squawk/config"
fi

: "${SQUAWK_ENABLE:=1}"
# 0 = persistent (never auto-dismiss). squawk clears a session's notification
# when you return to its pane, so notifications don't need to time out.
: "${SQUAWK_TIMEOUT:=0}"
: "${SQUAWK_DEBUG_LOG:=${TMPDIR:-/tmp}/squawk-debug.log}"
# Optional, may be unset: SQUAWK_DEBUG, SQUAWK_ICON, SQUAWK_APPROVE.

# The Claude desktop app, whose icon notifications borrow by default.
SQUAWK_CLAUDE_BUNDLE_ID="com.anthropic.claudefordesktop"

# approve_enabled -> 0 when the notification Approve button is on (the default).
# Set SQUAWK_APPROVE to 0/false/no/off to turn it off; permission notifications
# then just notify (like Notification) and you decide in the terminal.
approve_enabled() {
  case "${SQUAWK_APPROVE:-1}" in
    0 | false | no | off | "") return 1 ;;
    *) return 0 ;;
  esac
}

# reply_enabled -> 0 when the Stop notification's reply field is on (the default).
# Set SQUAWK_REPLY to 0/false/no/off to turn it off; "Finished" notifications then
# just notify (no reply, Stop stays non-blocking).
reply_enabled() {
  case "${SQUAWK_REPLY:-1}" in
    0 | false | no | off | "") return 1 ;;
    *) return 0 ;;
  esac
}

# resolve_terminal -> bundle id of the GUI app hosting this terminal, discovered
# by walking the process tree to the first ancestor whose executable lives in a
# .app bundle and reading its CFBundleIdentifier. It drives the frontmost-app
# comparison and the click-to-jump `activate`. Terminal-agnostic — any terminal
# works, with no built-in list and no configuration. Inside tmux the pane's
# processes hang off the detached server, so we start the walk from the attached
# client (which lives under the real terminal); otherwise from this process.
# Empty if nothing is found (callers then treat the terminal as not-frontmost
# and notify).
resolve_terminal() {
  local pid ppid comm app i
  if [ -n "${TMUX:-}" ]; then
    if [ -n "${TMUX_PANE:-}" ]; then
      pid="$(tmux display-message -p -t "$TMUX_PANE" '#{client_pid}' 2>/dev/null)"
    else
      pid="$(tmux display-message -p '#{client_pid}' 2>/dev/null)"
    fi
  fi
  [ -n "${pid:-}" ] || pid="$$"
  for ((i = 0; i < 20; i++)); do
    case "$pid" in '' | *[!0-9]*) return 0 ;; esac
    [ "$pid" -gt 1 ] || return 0
    read -r ppid comm < <(ps -o ppid=,comm= -p "$pid" 2>/dev/null) || true
    case "$comm" in
      */*.app/Contents/MacOS/*)
        app="${comm%%.app/*}.app"
        if defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null; then
          return 0
        fi
        ;;
    esac
    pid="$ppid"
  done
}

# claude_installed -> 0 if the Claude desktop app is present in a standard
# location (overridable as a function in tests).
claude_installed() {
  [ -d /Applications/Claude.app ] || [ -d "$HOME/Applications/Claude.app" ]
}

# resolve_icon -> the bundle id whose icon the notification should use (alerter
# --sender), or empty for the default. One knob, SQUAWK_ICON:
#   SQUAWK_ICON=<bundle id>  -> use that app's icon
#   SQUAWK_ICON=none         -> no impersonation (alerter's default icon)
#   unset + Claude installed -> the Claude icon
#   unset + no Claude        -> default icon
# Note: macOS silently drops notifications whose impersonated sender isn't
# authorized; set SQUAWK_ICON=none if notifications stop appearing.
resolve_icon() {
  if [ -n "${SQUAWK_ICON:-}" ]; then
    if [ "$SQUAWK_ICON" = "none" ]; then
      return 0
    fi
    printf '%s' "$SQUAWK_ICON"
    return 0
  fi
  if claude_installed; then
    printf '%s' "$SQUAWK_CLAUDE_BUNDLE_ID"
  fi
}
