# shellcheck shell=bash
# Side-effecting actions: the in-pane banner and the OS notification.

# set_banner <pane> <label>
# Paint an attention banner on the pane's border. A one-shot pane-focus-in hook
# reverts it (back to the global blank border format) the moment you focus the
# pane, then removes itself. Requires `focus-events on` and a non-empty
# `pane-border-status` in tmux (see share/tmux/squawk.tmux). Colors are any tmux
# color (name, colourN, or #hex) via SQUAWK_BANNER_BG / SQUAWK_BANNER_FG.
set_banner() {
  local pane="$1" label="$2"
  local bg="${SQUAWK_BANNER_BG:-yellow}" fg="${SQUAWK_BANNER_FG:-black}"
  tmux set-option -p -t "$pane" pane-border-format \
    "#[align=centre,fg=${fg},bg=${bg},bold] ⬤  ${label}  ⬤ "
  tmux set-hook -p -t "$pane" pane-focus-in \
    'set-option -pu pane-border-format ; set-hook -pu pane-focus-in'
}

# set_clear_on_focus <pane> <group> <sender>
# Arm a one-shot pane-focus-in hook that removes this session's notification when
# you return to the pane. A still-open Approve/Reply prompt closes too, so its
# alerter returns and squawk defers. <sender> must match how it was posted (the
# notification group is namespaced per sender). No-op without a group.
set_clear_on_focus() {
  local pane="$1" group="$2" sender="$3" bin remove
  [ -n "$group" ] || return 0
  bin="$(command -v alerter 2>/dev/null || echo alerter)"
  remove="$bin --remove '$group'"
  if [ -n "$sender" ]; then
    remove="$remove --sender '$sender'"
  fi
  tmux set-hook -p -t "$pane" pane-focus-in \
    "run-shell \"$remove >/dev/null 2>&1\" ; set-hook -pu pane-focus-in"
}

# jump_to_pane <pane> <terminal_bundle_id>
# Switch the tmux client to the pane and bring the terminal to the front.
jump_to_pane() {
  local pane="$1" app="$2"
  if [ -n "$pane" ]; then
    tmux switch-client -t "$pane" 2>/dev/null || true
  fi
  if [ -n "$app" ]; then
    osascript -e "tell application id \"$app\" to activate" >/dev/null 2>&1 || true
  fi
}

# _notify_args <title> <subtitle> <body> <group> -> populates the global `args`
# with the shared alerter flags (icon + group, JSON output). Caller appends
# --actions etc. Results are always parsed from JSON (.activationType / .value).
_notify_args() {
  local title="$1" subtitle="$2" body="$3" group="$4" icon
  args=(--message "$body" --title "$title" --subtitle "$subtitle"
    --timeout "${SQUAWK_TIMEOUT:-0}" --json)
  if [ -n "$group" ]; then
    args+=(--group "$group")
  fi
  icon="$(resolve_icon)"
  if [ -n "$icon" ]; then
    args+=(--sender "$icon")
  fi
}

# notify <title> <subtitle> <body> <pane> <terminal_bundle_id> <group>
# Plain notification (Stop / Notification). Its one button — labeled "Jump",
# overriding alerter's useless default "Show" — and a click on the body jump back
# to the pane. Notifications sharing <group> replace one another.
notify() {
  local pane="$4" app="$5" result kind
  local -a args
  _notify_args "$1" "$2" "$3" "$6"
  args+=(--actions "Jump")
  result="$(alerter "${args[@]}")"
  kind="$(jq -r '.activationType // ""' <<<"$result" 2>/dev/null)"
  # The only action is "jump", so any action/body click navigates.
  if [ "$kind" = "actionClicked" ] || [ "$kind" = "contentsClicked" ]; then
    jump_to_pane "$pane" "$app"
  fi
}

# notify_approve <title> <subtitle> <body> <pane> <terminal_bundle_id> <group>
# PermissionRequest notification with a single Approve button. Prints the hook's
# decision JSON to stdout: clicking Approve -> allow; clicking the body -> jump to
# the pane and defer; ignoring it (timeout/dismiss) -> defer to the terminal
# prompt. Approving is gated on the explicit Approve action only.
notify_approve() {
  local pane="$4" app="$5" result kind choice
  local -a args
  _notify_args "$1" "$2" "$3" "$6"
  args+=(--actions "Approve")
  result="$(alerter "${args[@]}")"
  kind="$(jq -r '.activationType // ""' <<<"$result" 2>/dev/null)"
  choice="$(jq -r '.activationValue // ""' <<<"$result" 2>/dev/null)"
  # A click on the notification body (rather than the button) jumps to the pane.
  if [ "$kind" = "contentsClicked" ]; then
    jump_to_pane "$pane" "$app"
    return 0
  fi
  permission_decision "$choice"
}

# notify_reply <title> <subtitle> <body> <pane> <terminal_bundle_id> <group>
# Stop notification with a text reply field. Typing a reply prints the Stop-hook
# decision JSON to stdout so Claude continues with your text; clicking the body
# jumps to the pane; ignoring it (timeout/dismiss) lets Claude stop normally.
notify_reply() {
  local pane="$4" app="$5" result kind value
  local -a args
  _notify_args "$1" "$2" "$3" "$6"
  args+=(--reply "Reply to continue…")
  result="$(alerter "${args[@]}")"
  kind="$(jq -r '.activationType // ""' <<<"$result" 2>/dev/null)"
  value="$(jq -r '.activationValue // ""' <<<"$result" 2>/dev/null)"
  if [ "$kind" = "contentsClicked" ]; then
    jump_to_pane "$pane" "$app"
    return 0
  fi
  if [ "$kind" = "replied" ]; then
    reply_decision "$value"
  fi
}
