#!/usr/bin/env bats
# Title/body building — real jq, fixture payloads.

setup() {
  # shellcheck source=../lib/payload.sh
  source "${BATS_TEST_DIRNAME}/../lib/payload.sh"
  FIX="${BATS_TEST_DIRNAME}/fixtures"
}

@test "label: Stop -> Finished" {
  run label_from_payload '{"hook_event_name":"Stop"}'
  [ "$output" = "Finished" ]
}

@test "label: PermissionRequest -> Needs your permission" {
  run label_from_payload '{"hook_event_name":"PermissionRequest"}'
  [ "$output" = "Needs your permission" ]
}

@test "label: Notification -> Needs your input" {
  run label_from_payload '{"hook_event_name":"Notification"}'
  [ "$output" = "Needs your input" ]
}

@test "label: unknown event -> Claude" {
  run label_from_payload '{}'
  [ "$output" = "Claude" ]
}

@test "label: overridable via SQUAWK_LABEL_STOP" {
  SQUAWK_LABEL_STOP="Done!" run label_from_payload '{"hook_event_name":"Stop"}'
  [ "$output" = "Done!" ]
}

@test "title is the last path segment of cwd" {
  run build_title '{"cwd":"/Users/x/projects/myapp"}'
  [ "$output" = "myapp" ]
}

@test "group is squawk-<session_id>" {
  run build_group '{"session_id":"abc123"}'
  [ "$output" = "squawk-abc123" ]
}

@test "group is empty when session_id missing" {
  run build_group '{}'
  [ -z "$output" ]
}

@test "title falls back to Claude when cwd missing" {
  run build_title '{}'
  [ "$output" = "Claude" ]
}

@test "body: Bash permission shows the command" {
  run build_body "$(cat "$FIX/permission_bash.json")" 'Needs your permission'
  [ "$output" = "Bash: git push origin main --force" ]
}

@test "body: Edit permission shows the file path" {
  run build_body "$(cat "$FIX/permission_edit.json")" 'Needs your permission'
  [ "$output" = "Edit: /Users/x/.zshrc" ]
}

@test "body: WebFetch permission shows the url" {
  run build_body "$(cat "$FIX/permission_webfetch.json")" 'Needs your permission'
  [ "$output" = "WebFetch: https://example.com/page" ]
}

@test "body: Notification strips leading 'Claude '" {
  run build_body "$(cat "$FIX/notification.json")" 'Needs your input'
  [ "$output" = "needs your input" ]
}

@test "body: Stop with no tool falls back to the label" {
  run build_body "$(cat "$FIX/stop.json")" 'Finished'
  [ "$output" = "Finished" ]
}

@test "body: Stop uses the inline last_assistant_message" {
  run build_body '{"hook_event_name":"Stop","last_assistant_message":"all wrapped up"}' 'Finished'
  [ "$output" = "all wrapped up" ]
}

@test "body: newlines collapsed and truncated with an ellipsis" {
  long="$(printf 'x%.0s' {1..200})"
  run build_body "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"a\nb $long\"}}" 'x'
  [[ "$output" != *$'\n'* ]]
  # "Bash: " (6) + 119 detail chars + the ellipsis
  [ "${#output}" -le 126 ]
  [[ "$output" == "Bash: a b "* ]]
  [[ "$output" == *… ]]
}

@test "body: a short command is shown without an ellipsis" {
  run build_body '{"tool_name":"Bash","tool_input":{"command":"git status"}}' 'x'
  [ "$output" = "Bash: git status" ]
}

@test "approve_safe: short single-line command is approvable" {
  approve_safe '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
}

@test "approve_safe: long command is not approvable" {
  long="$(printf 'x%.0s' {1..200})"
  run approve_safe "{\"tool_input\":{\"command\":\"$long\"}}"
  [ "$status" -ne 0 ]
}

@test "approve_safe: multi-line command is not approvable" {
  run approve_safe '{"tool_input":{"command":"git push\nrm -rf x"}}'
  [ "$status" -ne 0 ]
}

@test "approve_safe: missing command is not approvable" {
  run approve_safe '{}'
  [ "$status" -ne 0 ]
}
