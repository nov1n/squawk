# shellcheck shell=bash
# Installer: symlink the binary, merge the Claude Code hooks, and offer the tmux
# snippet. Idempotent and symlink-safe. Sourced by bin/squawk for the
# install/uninstall/check-deps subcommands; relies on $SQUAWK_ROOT being set.
#
# Honored env vars (also used by the test suite):
#   PREFIX            install prefix (default: $HOME/.local)
#   CLAUDE_SETTINGS   path to settings.json (default: $HOME/.claude/settings.json)
#   SQUAWK_TMUX_CONF  path to tmux config (default: $HOME/.tmux.conf)
#   SQUAWK_YES=1      non-interactive: append the tmux snippet without prompting

PREFIX="${PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin/squawk"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
TMUX_CONF="${SQUAWK_TMUX_CONF:-$HOME/.tmux.conf}"
MARK_BEGIN="# >>> squawk begin >>>"
MARK_END="# <<< squawk end <<<"

info() { printf '  %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

# Resolve symlinks to the real file path (portable: readlink -f, else python3).
realpath_f() {
  if readlink -f "$1" >/dev/null 2>&1; then
    readlink -f "$1"
  else
    python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1"
  fi
}

squawk_check_deps() {
  local missing=0 dep
  for dep in jq tmux osascript; do
    if command -v "$dep" >/dev/null 2>&1; then
      info "found $dep"
    else
      missing=1
      case "$dep" in
        osascript) warn "$dep not found — squawk requires macOS" ;;
        jq) warn "$dep not found — brew install jq" ;;
        tmux) warn "$dep not found — brew install tmux" ;;
      esac
    fi
  done
  if command -v alerter >/dev/null 2>&1; then
    info "found alerter"
  else
    warn "alerter not found — needed for OS notifications (the banner works without it). brew install vjeantet/tap/alerter"
  fi
  return "$missing"
}

# The real settings file behind a possible symlink (so we never clobber a
# dotfiles symlink with a regular file).
settings_target() {
  if [ -e "$SETTINGS" ]; then
    realpath_f "$SETTINGS"
  else
    printf '%s' "$SETTINGS"
  fi
}

merge_hooks() {
  local target tmp backup
  target="$(settings_target)"
  if [ ! -f "$target" ]; then
    mkdir -p "$(dirname "$target")"
    printf '{}' >"$target"
  fi
  backup="$target.squawk.bak.$(date +%s)"
  cp "$target" "$backup"
  info "backed up settings -> $backup"

  # The same command for every event — squawk derives the label from the
  # payload's hook_event_name. Only the matcher differs.
  tmp="$(mktemp "$(dirname "$target")/settings.XXXXXX")"
  jq --arg bin "$BIN" '
    # A squawk hook is one whose command is "<…>/squawk hook" — match that
    # precisely, NOT any command that merely contains "squawk" (which would
    # clobber a user hook like /opt/squawkbox/run.sh).
    def is_squawk: (.command // "") | test("(^|/)squawk hook($| )");
    # Drop any existing squawk entries from an event array, then append fresh.
    def strip(arr): (arr // []) | map(select(.hooks | all(is_squawk | not)));
    # Stop is synchronous (no async) so squawk can feed a reply back and continue
    # the conversation.
    .hooks.Stop = (strip(.hooks.Stop) + [
      {hooks: [{type: "command", command: ($bin + " hook")}]}
    ])
    # Only the Notification subtypes where Claude is actually waiting on you, so
    # the "Needs your input" label fits and we skip informational ones
    # (auth_success, elicitation_complete/response).
    | .hooks.Notification = (strip(.hooks.Notification) + [
      {matcher: "idle_prompt|elicitation_dialog",
       hooks: [{type: "command", command: ($bin + " hook"), async: true}]}
    ])
    # PermissionRequest is synchronous (no async) so squawk can answer the
    # prompt (approve/deny) from the notification.
    | .hooks.PermissionRequest = (strip(.hooks.PermissionRequest) + [
      {matcher: "*",
       hooks: [{type: "command", command: ($bin + " hook")}]}
    ])
    # StopFailure: the turn died on an API error (rate limit, server error, …).
    # Async — its output is ignored and there is nothing to answer; we just alert
    # you so a failed turn does not sit unnoticed while you are away.
    | .hooks.StopFailure = (strip(.hooks.StopFailure) + [
      {matcher: "*",
       hooks: [{type: "command", command: ($bin + " hook"), async: true}]}
    ])
  ' "$target" >"$tmp"
  mv "$tmp" "$target"
  info "merged squawk hooks -> $SETTINGS"
}

unmerge_hooks() {
  local target tmp backup
  target="$(settings_target)"
  if [ ! -f "$target" ]; then
    warn "no settings file at $SETTINGS"
    return 0
  fi
  backup="$target.squawk.bak.$(date +%s)"
  cp "$target" "$backup"

  tmp="$(mktemp "$(dirname "$target")/settings.XXXXXX")"
  jq '
    def is_squawk: (.command // "") | test("(^|/)squawk hook($| )");
    def clean(arr): (arr // [])
      | map(select(.hooks | all(is_squawk | not)))
      | map(select((.hooks | length) > 0));
    if .hooks then
      .hooks.Stop = clean(.hooks.Stop)
      | .hooks.Notification = clean(.hooks.Notification)
      | .hooks.PermissionRequest = clean(.hooks.PermissionRequest)
      | .hooks.StopFailure = clean(.hooks.StopFailure)
      | .hooks |= with_entries(select(.value | length > 0))
      | (if (.hooks | length) == 0 then del(.hooks) else . end)
    else . end
  ' "$target" >"$tmp"
  mv "$tmp" "$target"
  info "removed squawk hooks <- $SETTINGS"
}

install_tmux_snippet() {
  local snippet="$SQUAWK_ROOT/share/tmux/squawk.tmux"
  [ -f "$TMUX_CONF" ] || touch "$TMUX_CONF"
  if grep -qF "$MARK_BEGIN" "$TMUX_CONF" 2>/dev/null; then
    info "tmux snippet already present in $TMUX_CONF"
    return 0
  fi
  printf '\n' >>"$TMUX_CONF"
  cat "$snippet" >>"$TMUX_CONF"
  info "appended tmux snippet -> $TMUX_CONF (reload: tmux source-file $TMUX_CONF)"
}

# Print the tmux snippet to stdout for the user to add manually (the banner needs
# it). The snippet itself carries the "source this LAST" note.
print_tmux_snippet() {
  info "skipped — the in-pane banner needs this in your tmux config (add it last):"
  printf '\n'
  cat "$SQUAWK_ROOT/share/tmux/squawk.tmux"
  printf '\n'
}

remove_tmux_snippet() {
  [ -f "$TMUX_CONF" ] || return 0
  grep -qF "$MARK_BEGIN" "$TMUX_CONF" 2>/dev/null || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0 == b {skip = 1}
    skip && $0 == e {skip = 0; next}
    !skip {print}
  ' "$TMUX_CONF" >"$tmp"
  mv "$tmp" "$TMUX_CONF"
  info "removed tmux snippet <- $TMUX_CONF"
}

squawk_install() {
  squawk_check_deps || warn "some dependencies are missing (see above) — continuing"
  mkdir -p "$PREFIX/bin"
  ln -sf "$SQUAWK_ROOT/bin/squawk" "$BIN"
  info "linked $BIN -> $SQUAWK_ROOT/bin/squawk"
  case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) warn "$PREFIX/bin is not on your PATH — add it so the hooks can find squawk" ;;
  esac
  merge_hooks
  if [ "${SQUAWK_YES:-0}" = "1" ]; then
    install_tmux_snippet
  else
    printf 'Append the tmux banner prerequisite to %s? [y/N] ' "$TMUX_CONF"
    read -r ans || ans=""
    case "$ans" in
      [yY]*) install_tmux_snippet ;;
      *) print_tmux_snippet ;;
    esac
  fi
  info "done — restart Claude Code so it picks up the new hooks."
}

squawk_uninstall() {
  unmerge_hooks
  remove_tmux_snippet
  if [ -L "$BIN" ]; then
    rm -f "$BIN"
    info "removed $BIN"
  fi
  info "done."
}
