#!/usr/bin/env bats
# Terminal resolution: bundle id from override / $__CFBundleIdentifier / tmux.

setup() {
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  # Stub tmux so the show-environment fallback yields nothing.
  export PATH="${BATS_TEST_DIRNAME}/stubs:$PATH"
  unset SQUAWK_TERMINAL __CFBundleIdentifier SQUAWK_APPROVE SQUAWK_REPLY
  # shellcheck source=../lib/config.sh
  source "${BATS_TEST_DIRNAME}/../lib/config.sh"
}

@test "SQUAWK_TERMINAL override is used verbatim" {
  export SQUAWK_TERMINAL=com.example.term
  run resolve_terminal
  [ "$output" = "com.example.term" ]
}

@test "auto-detect from \$__CFBundleIdentifier" {
  export __CFBundleIdentifier=com.mitchellh.ghostty
  run resolve_terminal
  [ "$output" = "com.mitchellh.ghostty" ]
}

@test "SQUAWK_TERMINAL wins over \$__CFBundleIdentifier" {
  export SQUAWK_TERMINAL=com.a __CFBundleIdentifier=com.b
  run resolve_terminal
  [ "$output" = "com.a" ]
}

@test "no terminal info -> empty (callers then always notify)" {
  run resolve_terminal
  [ -z "$output" ]
}

@test "approve_enabled: on by default" {
  approve_enabled
}

@test "approve_enabled: 1/true/yes keep it on" {
  SQUAWK_APPROVE=1 run approve_enabled
  [ "$status" -eq 0 ]
  SQUAWK_APPROVE=true run approve_enabled
  [ "$status" -eq 0 ]
}

@test "approve_enabled: 0/false/no/off turn it off" {
  for v in 0 false no off; do
    SQUAWK_APPROVE="$v" run approve_enabled
    [ "$status" -ne 0 ]
  done
}

@test "reply_enabled: on by default, off via SQUAWK_REPLY" {
  reply_enabled
  for v in 0 false no off; do
    SQUAWK_REPLY="$v" run reply_enabled
    [ "$status" -ne 0 ]
  done
}
