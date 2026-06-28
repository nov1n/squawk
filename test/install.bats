#!/usr/bin/env bats
# Installer: symlink-safe, idempotent jq merge into settings.json.

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export PREFIX="$HOME/.local"
  export CLAUDE_SETTINGS="$HOME/.claude/settings.json"
  export SQUAWK_TMUX_CONF="$HOME/.tmux.conf"
  export SQUAWK_YES=1
  mkdir -p "$HOME/.claude" "$HOME/dotfiles"
  # Simulate a dotfiles-style symlinked settings.json with a pre-existing,
  # non-squawk Stop hook and an unrelated top-level key.
  cat >"$HOME/dotfiles/settings.json" <<'JSON'
{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo keep","async":true}]}]}}
JSON
  ln -s "$HOME/dotfiles/settings.json" "$CLAUDE_SETTINGS"
  ROOT="${BATS_TEST_DIRNAME}/.."
}

@test "install merges hooks, preserves the symlink, siblings, and is idempotent" {
  run "$ROOT/bin/squawk" install
  [ "$status" -eq 0 ]

  # Symlink preserved (not replaced by a regular file).
  [ -L "$CLAUDE_SETTINGS" ]

  # squawk hooks present — uniform command (label derived from the payload).
  run jq -r '.hooks.PermissionRequest[0].hooks[0].command' "$CLAUDE_SETTINGS"
  [ "$output" = "$HOME/.local/bin/squawk hook" ]
  run jq -r '.hooks.PermissionRequest[0].matcher' "$CLAUDE_SETTINGS"
  [ "$output" = "*" ]

  # Stop and PermissionRequest are synchronous (no async) so they can continue /
  # answer; Notification stays async (fire-and-forget).
  run jq -r '.hooks.PermissionRequest[0].hooks[0].async // "unset"' "$CLAUDE_SETTINGS"
  [ "$output" = "unset" ]
  run jq -r '.hooks.Stop[] | .hooks[] | select(.command | contains("squawk")) | (.async // "unset")' "$CLAUDE_SETTINGS"
  [ "$output" = "unset" ]
  run jq -r '.hooks.Notification[0].hooks[0].async' "$CLAUDE_SETTINGS"
  [ "$output" = "true" ]
  # Notification matches only the input-requiring subtypes (not informational ones).
  run jq -r '.hooks.Notification[0].matcher' "$CLAUDE_SETTINGS"
  [ "$output" = "idle_prompt|elicitation_dialog" ]

  # StopFailure alerts on a turn that died on an API error; async, matches all.
  run jq -r '.hooks.StopFailure[0].matcher' "$CLAUDE_SETTINGS"
  [ "$output" = "*" ]
  run jq -r '.hooks.StopFailure[0].hooks[0].async' "$CLAUDE_SETTINGS"
  [ "$output" = "true" ]

  # Unrelated key preserved.
  run jq -r '.model' "$CLAUDE_SETTINGS"
  [ "$output" = "opus" ]

  # Sibling Stop hook preserved alongside the squawk one.
  run jq '.hooks.Stop | length' "$CLAUDE_SETTINGS"
  [ "$output" -eq 2 ]

  # Idempotent: a second run does not duplicate.
  run "$ROOT/bin/squawk" install
  [ "$status" -eq 0 ]
  run jq '.hooks.Stop | length' "$CLAUDE_SETTINGS"
  [ "$output" -eq 2 ]
  run jq '.hooks.PermissionRequest | length' "$CLAUDE_SETTINGS"
  [ "$output" -eq 1 ]
}

@test "install backs up the resolved target file" {
  run "$ROOT/bin/squawk" install
  [ "$status" -eq 0 ]
  run bash -c 'ls "$HOME"/dotfiles/settings.json.squawk.bak.* 2>/dev/null | wc -l'
  [ "$output" -ge 1 ]
}

@test "install appends the tmux snippet once" {
  "$ROOT/bin/squawk" install
  run grep -c '>>> squawk begin >>>' "$SQUAWK_TMUX_CONF"
  [ "$output" -eq 1 ]
  "$ROOT/bin/squawk" install
  run grep -c '>>> squawk begin >>>' "$SQUAWK_TMUX_CONF"
  [ "$output" -eq 1 ]
}

@test "uninstall removes squawk hooks but keeps siblings and the symlink" {
  "$ROOT/bin/squawk" install
  run "$ROOT/bin/squawk" uninstall
  [ "$status" -eq 0 ]

  [ -L "$CLAUDE_SETTINGS" ]

  # Only the original sibling Stop hook remains.
  run jq '.hooks.Stop | length' "$CLAUDE_SETTINGS"
  [ "$output" -eq 1 ]
  run jq -r '.hooks.Stop[0].hooks[0].command' "$CLAUDE_SETTINGS"
  [ "$output" = "echo keep" ]

  # Empty event arrays pruned.
  run jq '.hooks.PermissionRequest // "gone"' "$CLAUDE_SETTINGS"
  [ "$output" = '"gone"' ]
  run jq '.hooks.StopFailure // "gone"' "$CLAUDE_SETTINGS"
  [ "$output" = '"gone"' ]

  # tmux snippet stripped.
  run grep -c '>>> squawk begin >>>' "$SQUAWK_TMUX_CONF"
  [ "$output" -eq 0 ]
}

@test "a user hook whose path merely contains 'squawk' is never touched" {
  # A genuine user hook at /opt/squawkbox/run.sh must survive install AND
  # uninstall — squawk matches its own '<bin>/squawk hook' command, not the
  # substring 'squawk'.
  cat >"$HOME/dotfiles/settings.json" <<'JSON'
{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/opt/squawkbox/run.sh"}]}]}}
JSON

  "$ROOT/bin/squawk" install
  run jq -r '[.hooks.Stop[].hooks[].command] | index("/opt/squawkbox/run.sh") != null' "$CLAUDE_SETTINGS"
  [ "$output" = "true" ]

  "$ROOT/bin/squawk" uninstall
  run jq -r '.hooks.Stop[0].hooks[0].command' "$CLAUDE_SETTINGS"
  [ "$output" = "/opt/squawkbox/run.sh" ]
}
