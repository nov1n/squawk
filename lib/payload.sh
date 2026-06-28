# shellcheck shell=bash
# Build the notification title and body from the hook's JSON payload (stdin).
# Uses real jq (a hard dependency) — never stubbed in tests.

# label_from_payload <payload_json> -> a short label for the event, from
# .hook_event_name.
label_from_payload() {
  local event
  event="$(jq -r '.hook_event_name // ""' <<<"$1" 2>/dev/null)"
  case "$event" in
    Stop) printf '%s' "Finished" ;;
    StopFailure) printf '%s' "Turn failed" ;;
    PermissionRequest) printf '%s' "Needs your permission" ;;
    Notification) printf '%s' "Needs your input" ;;
    *) printf '%s' "Claude" ;;
  esac
}

# build_title <payload_json> -> project name (last path segment of .cwd), else "Claude"
build_title() {
  local cwd
  cwd="$(jq -r '.cwd // ""' <<<"$1" 2>/dev/null)"
  cwd="${cwd##*/}"
  printf '%s' "${cwd:-Claude}"
}

# build_group <payload_json> -> "squawk-<session_id>" (empty if no session_id).
# Notifications sharing a group replace one another, so a Claude session's
# notifications coalesce instead of stacking up.
build_group() {
  local sid
  sid="$(jq -r '.session_id // ""' <<<"$1" 2>/dev/null)"
  if [ -n "$sid" ]; then
    printf 'squawk-%s' "$sid"
  fi
}

# Longest tool argument shown in full. Longer is truncated with an ellipsis and
# is NOT one-click-approvable (see approve_safe).
SQUAWK_DETAIL_MAX=120

# _clip <text> -> single-lined and capped at SQUAWK_DETAIL_MAX, with a trailing
# ellipsis when truncated so hidden text is always obvious.
_clip() {
  local s
  s="$(printf '%s' "$1" | tr '\n' ' ')"
  if [ "${#s}" -gt "$SQUAWK_DETAIL_MAX" ]; then
    s="$(printf '%s' "$s" | cut -c1-$((SQUAWK_DETAIL_MAX - 1)))…"
  fi
  printf '%s' "$s"
}

# _tool_detail <payload_json> -> the tool's key argument, raw and untruncated.
_tool_detail() {
  jq -r '
    .tool_input.command // .tool_input.file_path // .tool_input.url
    // .tool_input.pattern // .tool_input.path // empty
  ' <<<"$1" 2>/dev/null
}

# build_body <payload_json> <label>
# Priority:
#   1. PermissionRequest: "<tool>: <key arg>" (command / file_path / url / pattern / path)
#   2. Notification: the .message text, leading "Claude " stripped
#   3. Stop: Claude's last message (.last_assistant_message)
#   4. Fallback: the label
build_body() {
  local payload="$1" label="$2" tool detail message last
  tool="$(jq -r '.tool_name // ""' <<<"$payload" 2>/dev/null)"
  if [ -n "$tool" ]; then
    detail="$(_tool_detail "$payload")"
    if [ -n "$detail" ]; then
      printf '%s: %s' "$tool" "$(_clip "$detail")"
    else
      printf '%s' "$tool"
    fi
    return
  fi

  message="$(jq -r '.message // ""' <<<"$payload" 2>/dev/null | sed 's/^Claude //')"
  if [ -n "$message" ]; then
    printf '%s' "$message"
    return
  fi

  # Stop (no tool, no message): show what Claude just said, not the bare label.
  # The Stop payload carries it inline as .last_assistant_message.
  last="$(jq -r '.last_assistant_message // ""' <<<"$payload" 2>/dev/null)"
  if [ -n "$last" ]; then
    printf '%s' "$(_clip "$last")"
  else
    printf '%s' "$label"
  fi
}

# approve_safe <payload_json> -> 0 only if the tool's key argument is short and
# single-line enough to be shown IN FULL in the notification. The Approve button
# is offered only then, so it can never hide part of a (possibly chained) command
# behind truncation. Longer/multi-line commands get a notify-only prompt — review
# and approve them in the terminal.
approve_safe() {
  local detail
  detail="$(_tool_detail "$1")"
  [ -n "$detail" ] || return 1
  case "$detail" in *$'\n'*) return 1 ;; esac
  [ "${#detail}" -le "$SQUAWK_DETAIL_MAX" ] || return 1
  return 0
}
