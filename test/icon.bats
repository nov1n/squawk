#!/usr/bin/env bats
# Notification icon resolution (SQUAWK_ICON / Claude auto-detect).

setup() {
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  unset SQUAWK_ICON
  # shellcheck source=../lib/config.sh
  source "${BATS_TEST_DIRNAME}/../lib/config.sh"
}

@test "explicit SQUAWK_ICON wins" {
  export SQUAWK_ICON=com.example.term
  [ "$(resolve_icon)" = "com.example.term" ]
}

@test "SQUAWK_ICON=none disables impersonation" {
  export SQUAWK_ICON=none
  [ -z "$(resolve_icon)" ]
}

@test "auto: Claude not installed -> empty" {
  claude_installed() { return 1; }
  [ -z "$(resolve_icon)" ]
}

@test "auto: Claude installed -> Claude bundle id" {
  claude_installed() { return 0; }
  [ "$(resolve_icon)" = "com.anthropic.claudefordesktop" ]
}
