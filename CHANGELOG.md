# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-27

### Added

- Initial release: a Claude Code notification hook for tmux + macOS.
- Three reactions based on whether you can see the originating pane: do nothing,
  an in-pane attention banner, or a macOS notification with click-to-jump.
- Hooks for `Stop`, `Notification` (non-permission waits), and `PermissionRequest`.
  All three call the same `squawk` command; the label is derived from the
  payload's `hook_event_name`.
- Zero-config, terminal-agnostic terminal detection: walks the process tree to
  the GUI app that owns the terminal (starting from the attached tmux client) and
  reads its bundle id — used for both the frontmost check and the click-to-jump
  `activate`. No built-in terminal list and no configuration, and it tracks the
  terminal you're currently attached from.
- Notification icon: borrows the Claude for Desktop icon when installed; override
  with `SQUAWK_ICON=<bundle id>` or disable with `SQUAWK_ICON=none`.
- Notifications from the same Claude session share a `--group` (`squawk-<session_id>`),
  so a newer one replaces the previous instead of stacking up.
- The in-pane banner is fully restyleable via a single `SQUAWK_BANNER` tmux
  `pane-border-format` template (`{label}` placeholder) — colors, symbols,
  padding/width, alignment; defaults to yellow-on-black with ⬤ markers.
- Returning to the pane clears that session's notification via a one-shot tmux
  `pane-focus-in` hook (`alerter --remove`), which also cancels a still-open
  Approve/Reply prompt so you decide in the terminal.
- "Finished" (Stop) notifications show Claude's last message in the body (from the
  hook's inline `last_assistant_message`) instead of repeating the "Finished" label.
- Notifications are persistent by default (`SQUAWK_TIMEOUT=0`) — there's no need
  to auto-dismiss them now that returning to the pane clears them. Set
  `SQUAWK_TIMEOUT` to a number to cap how long a notification (and a blocking
  Approve/Reply hook) waits.
- Approve permission requests straight from the notification: an away permission
  prompt shows an Approve button (or click the body to jump to the pane) and
  answers the prompt on your behalf. The `PermissionRequest` hook is synchronous;
  only an explicit Approve runs the tool, anything else defers to the terminal
  prompt (where you can deny or inspect it). Disable the button with
  `SQUAWK_APPROVE=0` for notify-only.
- Long/multi-line commands are truncated with a trailing `…` and the Approve
  button is withheld unless the command is shown in full — so a chained command
  can never be one-click-approved with its tail hidden.
- Reply from the notification: an away "Finished" (Stop) notification shows a
  reply field, and your reply continues the conversation (the Stop hook returns a
  `block` decision with your text). Synchronous like Approve, so it blocks a
  finished turn while you're away; disable with `SQUAWK_REPLY=0`.
- Plain notifications (Notification / reply- or approve-disabled) use a single
  "Jump" action instead of alerter's default "Show"; a body click also jumps. All
  results parsed via JSON.
- `squawk install` / `uninstall` / `check-deps` subcommands, with a symlink-safe,
  idempotent settings.json merge.
- bats test suite, shellcheck + shfmt, GitHub Actions CI.

[Unreleased]: https://github.com/nov1n/squawk/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nov1n/squawk/releases/tag/v0.1.0
