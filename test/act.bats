#!/usr/bin/env bats
# Side-effecting actions via PATH stubs (tmux/osascript/alerter). jq is real.

setup() {
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export PATH="${BATS_TEST_DIRNAME}/stubs:$PATH"
  export SQUAWK_TIMEOUT=10
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  unset SQUAWK_ICON SQUAWK_BANNER SQUAWK_SOUND
  # shellcheck source=../lib/config.sh
  source "${BATS_TEST_DIRNAME}/../lib/config.sh"
  # shellcheck source=../lib/decide.sh
  source "${BATS_TEST_DIRNAME}/../lib/decide.sh"
  # shellcheck source=../lib/act.sh
  source "${BATS_TEST_DIRNAME}/../lib/act.sh"
  # Default to "no Claude" so --sender behavior is deterministic across machines.
  claude_installed() { return 1; }
}

@test "set_banner issues the set-option and set-hook pair" {
  set_banner '%3' 'Finished'
  grep -q 'set-option -p -t %3 pane-border-format' "$STUB_LOG"
  grep -q 'set-hook -p -t %3 pane-focus-in' "$STUB_LOG"
}

@test "set_banner default format styles the label and substitutes {label}" {
  set_banner '%3' 'Finished'
  grep -q 'bg=yellow' "$STUB_LOG"
  grep -qF 'Finished' "$STUB_LOG"
  # the placeholder is substituted, never left literal
  ! grep -qF '{label}' "$STUB_LOG"
}

@test "set_banner honors a custom SQUAWK_BANNER template" {
  SQUAWK_BANNER='#[bg=blue]>> {label} <<' set_banner '%3' 'Done'
  grep -qF '#[bg=blue]>> Done <<' "$STUB_LOG"
}

@test "set_clear_on_focus arms a pane-focus-in hook that removes the group" {
  set_clear_on_focus '%3' 'squawk-S' 'com.x'
  grep -q 'set-hook -p -t %3 pane-focus-in' "$STUB_LOG"
  grep -q -- '--remove' "$STUB_LOG"
  grep -q 'squawk-S' "$STUB_LOG"
}

@test "set_clear_on_focus with no group is a no-op" {
  set_clear_on_focus '%3' '' 'com.x'
  ! grep -q 'pane-focus-in' "$STUB_LOG"
}

@test "notify uses a single jump action and omits --sender with no icon" {
  ALERTER_RESULT='{"activationType":"timeout"}' notify 'proj' 'lbl' 'body' '%3' 'com.mitchellh.ghostty' ''
  grep -qF -- '--actions Jump' "$STUB_LOG"
  ! grep -q -- '--sender' "$STUB_LOG"
}

@test "notify with SQUAWK_ICON includes --sender" {
  export SQUAWK_ICON=com.example.x
  ALERTER_RESULT='{"activationType":"timeout"}' notify 'proj' 'lbl' 'body' '%3' 'com.mitchellh.ghostty' ''
  grep -q -- '--sender com.example.x' "$STUB_LOG"
}

@test "notify is silent by default (no --sound)" {
  ALERTER_RESULT='{"activationType":"timeout"}' notify 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' ''
  ! grep -q -- '--sound' "$STUB_LOG"
}

@test "notify with SQUAWK_SOUND includes --sound" {
  export SQUAWK_SOUND=Glass
  ALERTER_RESULT='{"activationType":"timeout"}' notify 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' ''
  grep -q -- '--sound Glass' "$STUB_LOG"
}

@test "timeout result does not jump back" {
  ALERTER_RESULT='{"activationType":"timeout"}' notify 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' ''
  ! grep -q 'switch-client' "$STUB_LOG"
}

@test "clicking the body jumps back: switch-client + activate by bundle id" {
  ALERTER_RESULT='{"activationType":"contentsClicked"}' notify 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' ''
  grep -q 'switch-client -t %3' "$STUB_LOG"
  grep -q 'tell application id "com.mitchellh.ghostty" to activate' "$STUB_LOG"
}

@test "clicking the Jump action jumps back" {
  ALERTER_RESULT='{"activationType":"actionClicked","activationValue":"Jump"}' notify 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' ''
  grep -q 'switch-client -t %3' "$STUB_LOG"
}

@test "notify with a group adds --group" {
  ALERTER_RESULT='{"activationType":"timeout"}' notify 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' 'squawk-abc123'
  grep -q -- '--group squawk-abc123' "$STUB_LOG"
}

@test "notify without a group omits --group" {
  ALERTER_RESULT='{"activationType":"timeout"}' notify 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' ''
  ! grep -q -- '--group' "$STUB_LOG"
}

@test "notify_approve sends a single Approve action (no dropdown)" {
  ALERTER_RESULT='{"activationType":"timeout"}' notify_approve 'p' 'l' 'b' '%3' 'com.x' '' >/dev/null
  grep -qF -- '--actions Approve' "$STUB_LOG"
  ! grep -q -- 'Deny' "$STUB_LOG"
  ! grep -q -- 'Show' "$STUB_LOG"
  ! grep -q -- 'dropdown-label' "$STUB_LOG"
}

@test "notify_approve: Approve -> allow JSON, no jump" {
  out="$(ALERTER_RESULT='{"activationType":"actionClicked","activationValue":"Approve"}' \
    notify_approve 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' '')"
  echo "$out" | jq -e '.hookSpecificOutput.decision.behavior == "allow"'
  ! grep -q 'switch-client' "$STUB_LOG"
}


@test "notify_approve: timeout -> no decision, no jump (defer)" {
  out="$(ALERTER_RESULT='{"activationType":"timeout"}' \
    notify_approve 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' '')"
  [ -z "$out" ]
  ! grep -q 'switch-client' "$STUB_LOG"
}

@test "notify_approve: clicking the body jumps back, no decision" {
  out="$(ALERTER_RESULT='{"activationType":"contentsClicked"}' \
    notify_approve 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' '')"
  [ -z "$out" ]
  grep -q 'switch-client -t %3' "$STUB_LOG"
  grep -q 'tell application id "com.mitchellh.ghostty" to activate' "$STUB_LOG"
}

@test "notify_reply sends a --reply field" {
  ALERTER_RESULT='{"activationType":"timeout"}' notify_reply 'p' 'l' 'b' '%3' 'com.x' '' >/dev/null
  grep -q -- '--reply' "$STUB_LOG"
}

@test "notify_reply: a typed reply -> block decision with the reply" {
  out="$(ALERTER_RESULT='{"activationType":"replied","activationValue":"keep going"}' \
    notify_reply 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' '')"
  echo "$out" | jq -e '.decision == "block" and .reason == "keep going"'
}

@test "notify_reply: empty reply -> nothing (stop proceeds)" {
  out="$(ALERTER_RESULT='{"activationType":"replied","activationValue":""}' \
    notify_reply 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' '')"
  [ -z "$out" ]
}

@test "notify_reply: timeout -> nothing, no jump" {
  out="$(ALERTER_RESULT='{"activationType":"timeout"}' \
    notify_reply 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' '')"
  [ -z "$out" ]
  ! grep -q 'switch-client' "$STUB_LOG"
}

@test "notify_reply: clicking the body jumps back, no continue" {
  out="$(ALERTER_RESULT='{"activationType":"contentsClicked"}' \
    notify_reply 'p' 'l' 'b' '%3' 'com.mitchellh.ghostty' '')"
  [ -z "$out" ]
  grep -q 'switch-client -t %3' "$STUB_LOG"
}
