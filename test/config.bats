#!/usr/bin/env bats
# Config toggles: approve / reply enablement. (Terminal resolution lives in
# detect.bats.)

setup() {
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  unset SQUAWK_APPROVE SQUAWK_REPLY
  # shellcheck source=../lib/config.sh
  source "${BATS_TEST_DIRNAME}/../lib/config.sh"
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
