<p align="center">
  <img src="https://github.com/user-attachments/assets/49a1b6dc-b792-42fb-8121-a81c6aac30c4" alt="Logo" height=150>
</p>

# squawk

`squawk` transforms Claude's events—like a finished turn, an input prompt, or a
permission request into context-aware notifications. Instead of constantly
pinging you, it detects if Claude is visible and chooses the least intrusive
alert possible. When you do get a notification, you can jump straight to the
active pane with a single click, or reply and approve directly from the alert
without breaking your workflow.

## Features

- **Pane-aware** — silent when you're looking at the pane, a **banner** on an
  adjacent split, a **macOS notification** only when you're truly away.
- **Reply from the notification** — answer a "Finished" notification and Claude
  **continues the conversation**; no trip back to the terminal.
- **Approve from the notification** — one-click _allow_ a permission prompt.
- **Message preview** — "Finished" notifications show Claude's actual last
  message, not just the word "Finished".
- **Persistent + self-clearing** — notifications stay until you deal with them,
  and clear automatically the moment you return to the pane.
- **Per-session grouping** — a session's notifications replace each other
  instead of stacking up.
- **Zero-config** — auto-detects your terminal; nothing to set beyond install.

## Demo

<details>
<summary>Watch the demo</summary>

https://github.com/user-attachments/assets/a06acd74-dd22-4a0c-9f35-bc0d9dba9de6

</details>

## Requirements

- **macOS** (uses `osascript` +
  [`alerter`](https://github.com/vjeantet/alerter))
- **tmux**, **jq**
- **Claude Code**

```bash
brew install jq tmux
brew install vjeantet/tap/alerter
```

## Install

```bash
git clone https://github.com/nov1n/squawk ~/.local/share/squawk
~/.local/share/squawk/bin/squawk install
```

Keep the clone where it is — `squawk install` symlinks to it and reads its
`lib/` at runtime (so `git pull` upgrades in place). `squawk install`:

1. Checks if required dependencies are correctly installed.
2. Symlinks `squawk` into `~/.local/bin` (override with `PREFIX=`).
3. Merges three hooks (`Stop`, `Notification`, `PermissionRequest`) into
   `~/.claude/settings.json` — **idempotent** and **symlink-safe**.
4. Offers to append the tmux prerequisite snippet to `~/.tmux.conf`.

> **Restart Claude Code** after installing so it loads the new hooks.

### tmux prerequisite

The banner swaps a pane's `pane-border-format`, which needs the border status
line reserved and focus events on:

```tmux
set -g focus-events on
set -g pane-border-status top
set -g pane-border-format ''
```

`squawk install` can add this for you. If you prefer to do this manually, make
sure to place it last in your tmux config — some themes (e.g.
`tokyo-night-tmux`) turn `pane-border-status` off, so squawk has to load after
them to win.

## Configuration

All via environment variables (or an optional `~/.config/squawk/config` that's
sourced if present):

| Variable           | Default                    | Purpose                                                                                                                                                                                                                        |
| ------------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `SQUAWK_ICON`      | _(auto)_                   | Bundle id whose **icon** the notification uses (`alerter --sender`). Defaults to the **Claude icon** when Claude for Desktop is installed in a standard path. Set a bundle id to use another app's icon, or `none` to disable. |
| `SQUAWK_TIMEOUT`   | `0`                        | Seconds before a notification auto-dismisses. `0` keeps it **persistent** (squawk clears it when you return to the pane). Set a number to auto-dismiss instead.                                                                |
| `SQUAWK_BANNER`    | _(yellow ⬤ style)_         | Full tmux `pane-border-format` for the in-pane banner; `{label}` is replaced with the event. Restyle colors, symbols, padding/width, and alignment — e.g. `#[align=left,bg=magenta,fg=white,bold] ▶ {label} `.                 |
| `SQUAWK_APPROVE`   | `1`                        | Show the Approve button on permission notifications. Set to `0` for notify-only (decide in the terminal).                                                                                                                      |
| `SQUAWK_REPLY`     | `1`                        | Show a reply field on "Finished" notifications (your reply continues the conversation). Set to `0` for notify-only.                                                                                                            |
| `SQUAWK_ENABLE`    | `1`                        | Set to `0` to disable squawk entirely.                                                                                                                                                                                         |
| `SQUAWK_DEBUG`     | _(unset)_                  | Set to log decisions to `SQUAWK_DEBUG_LOG`.                                                                                                                                                                                    |
| `SQUAWK_DEBUG_LOG` | `$TMPDIR/squawk-debug.log` | Debug log path.                                                                                                                                                                                                                |

> **Notification icon.** With Claude for Desktop installed, notifications carry
> the Claude icon automatically (squawk passes its bundle id to `alerter`). If
> notifications stop appearing, see [the FAQ](#faq-notifications).

## Uninstall

```bash
squawk uninstall
```

Removes the hooks (preserving siblings), the `~/.local/bin/squawk` symlink, and
the tmux snippet.

## Development

```bash
make test    # bats suite
make lint    # shellcheck + shfmt
make fmt     # auto-format
```

## FAQ

<details id="faq-notifications">
<summary>Why am I not getting notifications?</summary>

macOS must allow notifications for the app whose icon squawk borrows (Claude
Desktop by default). Open **System Settings → Notifications → Claude**, turn on
**Allow Notifications**, and set the style to **Alerts** so the reply/approve
buttons appear and persist. If notifications still don't show, macOS may be
dropping the impersonated sender — set `SQUAWK_ICON=none` to use the default
icon.

![Claude notification permissions in macOS System Settings](assets/claude-permissions.png)

</details>

<details id="faq-reply">
<summary>Can I reply to Claude from the notification?</summary>

When Claude finishes and you're away from the pane, the notification has a
**reply field** — type a response and Claude continues with it, no trip back to
the terminal. Dismiss it (or return to the pane, which clears it) and Claude
just stops; click the body to jump to the pane instead. Disable with
`SQUAWK_REPLY=0`.

</details>

<details id="faq-approve">
<summary>Can I approve a permission request from the notification?</summary>

An away permission prompt shows an **Approve** button. Approve runs the tool;
clicking the body jumps to the pane; dismissing (or returning to the pane) falls
back to the normal terminal prompt. Only an explicit Approve ever runs the tool
— timeouts, dismissals, and anything ambiguous defer to the terminal. Disable
with `SQUAWK_APPROVE=0`.

</details>

<details id="faq-approve-button">
<summary>Why doesn't the Approve button show up?</summary>

**The command is too long or multi-line.** You can't safely approve what you
can't fully see, so when it doesn't fit, the body is truncated with `…` and the
button is withheld — click the body to open the pane and approve the full
command there.

</details>

<details id="faq-blocking">
<summary>Why does Claude wait instead of stopping when I'm away?</summary>

Reply and approve answer on your behalf, so the hook stays open while you're
away: a finished turn waits for your reply, and a permission prompt waits for
your decision. Dismiss the notification (or return to the pane) to proceed
immediately, or set `SQUAWK_TIMEOUT` to a number of seconds to cap the wait.
This needs a synchronous hook, so it doesn't apply in headless (`claude -p`)
mode.

</details>

<details id="faq-multiple-clients">
<summary>Does squawk support multiple tmux clients?</summary>

Not fully. If two terminal windows are attached to the same tmux session, squawk
can't tell which one you're looking at, so it may stay quiet when it should
notify. A single window — with any splits, windows, and detached sessions — is
fully handled.

</details>

<details id="faq-terminal-detection">
<summary>How does squawk detect my terminal?</summary>

squawk walks up the process tree to the GUI app that owns your terminal and
reads its **bundle id**. It's terminal-agnostic — any terminal works with no
configuration and no built-in list. Inside tmux it starts from the _attached
client_ (the pane's processes hang off tmux's detached server), so it correctly
identifies the terminal you're currently attached from, even if the tmux server
was first started elsewhere.

</details>

## AI disclosure

squawk was built almost entirely with Claude Code. The design, implementation,
and tests were produced through AI pair-programming under human direction and
review.

## License

[MIT](LICENSE)
