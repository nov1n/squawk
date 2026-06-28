#!/usr/bin/env bats
# resolve_terminal: walk the process tree (from the tmux client) to the owning
# .app and read its bundle id. tmux / ps / defaults are PATH-stubbed.

setup() {
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$STUB_LOG"
  export PATH="${BATS_TEST_DIRNAME}/stubs:$PATH"
  # shellcheck source=../lib/config.sh
  source "${BATS_TEST_DIRNAME}/../lib/config.sh"
}

@test "walks from the tmux client up to the owning .app bundle id" {
  export TMUX=/tmp/sock,1,0 TMUX_PANE=%1
  export TMUX_CLIENT_PID=100
  export PS_100="200 tmux"
  # A terminal whose app path even contains a space, to exercise quoting.
  export PS_200="300 /Applications/Foo Term.app/Contents/MacOS/foo"
  export DEFAULTS_BID=com.foo.term
  run resolve_terminal
  [ "$output" = "com.foo.term" ]
}

@test "returns empty when no .app ancestor is found" {
  export TMUX=/tmp/sock,1,0 TMUX_PANE=%1
  export TMUX_CLIENT_PID=100
  export PS_100="200 tmux"
  export PS_200="1 /usr/bin/login"
  run resolve_terminal
  [ -z "$output" ]
}

@test "stops at the first app and reports it" {
  export TMUX=/tmp/sock,1,0 TMUX_PANE=%1
  export TMUX_CLIENT_PID=100
  export PS_100="200 /Applications/Iterm.app/Contents/MacOS/iTerm2"
  export DEFAULTS_BID=com.googlecode.iterm2
  run resolve_terminal
  [ "$output" = "com.googlecode.iterm2" ]
}
