#!/usr/bin/env bats
# Pure decision matrix — no mocks needed.

setup() {
  # shellcheck source=../lib/decide.sh
  source "${BATS_TEST_DIRNAME}/../lib/decide.sh"
}

# decide <frontmost> <in_tmux> <session_attached> <window_active> <pane_active>

@test "terminal not frontmost -> NOTIFY" {
  run decide 0 1 1 1 1
  [ "$output" = "NOTIFY" ]
}

@test "frontmost but not in tmux -> NOTIFY" {
  run decide 1 0 0 0 0
  [ "$output" = "NOTIFY" ]
}

@test "frontmost, focused pane -> NOTHING" {
  run decide 1 1 1 1 1
  [ "$output" = "NOTHING" ]
}

@test "frontmost, visible but unfocused pane -> BANNER" {
  run decide 1 1 1 1 0
  [ "$output" = "BANNER" ]
}

@test "frontmost, another tmux window -> NOTIFY" {
  run decide 1 1 1 0 1
  [ "$output" = "NOTIFY" ]
}

@test "frontmost, detached session -> NOTIFY" {
  run decide 1 1 0 1 1
  [ "$output" = "NOTIFY" ]
}

@test "permission_decision: Approve -> allow JSON" {
  run permission_decision Approve
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PermissionRequest" and .hookSpecificOutput.decision.behavior == "allow"'
}

@test "permission_decision: Deny -> deny JSON" {
  run permission_decision Deny
  echo "$output" | jq -e '.hookSpecificOutput.decision.behavior == "deny"'
}

@test "permission_decision: Show -> nothing (defer)" {
  run permission_decision Show
  [ -z "$output" ]
}

@test "permission_decision: empty/unknown -> nothing (defer)" {
  run permission_decision ""
  [ -z "$output" ]
  run permission_decision Whatever
  [ -z "$output" ]
}

@test "reply_decision: non-empty -> block decision with the reply as reason" {
  run reply_decision 'do the thing "now"'
  echo "$output" | jq -e '.decision == "block" and .reason == "do the thing \"now\""'
}

@test "reply_decision: empty -> nothing (stop proceeds)" {
  run reply_decision ""
  [ -z "$output" ]
}
