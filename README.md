# tmux-agent-notify

[![tmux](https://img.shields.io/badge/tmux-%E2%89%A5%203.0-1BB91F?logo=tmux&logoColor=white)](https://github.com/tmux/tmux)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

You run CLI coding agents (Claude Code, Codex, OpenCode, Antigravity) in tmux windows. While you
work in one window, an agent in another window stops and waits for you — and you don't see it.
This plugin makes tmux tell you: when an agent needs your input, finishes, or fails, its window
gets a marker in the status bar:

```text
[dev]  1:vim  2:claude ⏸  3:codex ✔  4:agy !          14:32
```

- `⏸` yellow — waiting for permission or asked a question
- `✔` green — turn finished
- `✖` red — error
- `!` yellow — bell from a known agent (fallback for agents without hooks)

A marker disappears when you visit the window or when the agent starts working again.
`prefix + a` jumps to the next marked window.

## How it works

No daemon, no polling, no state files. Each agent has a built-in way to run a command on events
(hooks). Those hooks call `scripts/notify.sh`, which writes the state into tmux window options
(`@agent_state`, `@agent_name`). The status line reads the options with tmux format strings. When
a window closes, its state goes with it.

## Requirements

- tmux ≥ 3.0
- `jq` (Claude hook parsing, installer)

## Install

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'romanvolkov/tmux-agent-notify'
```

Or manually:

```tmux
run-shell /path/to/tmux-agent-notify/agent-notify.tmux
```

Load the plugin after your theme. It appends to `window-status-format` /
`window-status-current-format`, so anything that sets those formats must run first. It also
enables `focus-events` and `monitor-bell`, and uses indexed hook slots (`[37]`) so your own hooks
are not touched.

## Wire up the agents

```bash
# print config snippets for manual setup:
scripts/install-hooks.sh

# or patch configs (idempotent, creates .bak backups):
scripts/install-hooks.sh --apply
```

| Agent | Mechanism | Events → states |
|---|---|---|
| Claude Code | hooks in `~/.claude/settings.json` | `Notification` → permission/question, `Stop` → done, `UserPromptSubmit` → clears |
| Codex | `notify` in `~/.codex/config.toml` | `agent-turn-complete` → done, approval events → permission |
| OpenCode | plugin in `~/.config/opencode/plugin/` | `session.idle` → done, `permission.*` → permission, `session.error` → error |
| Antigravity, others | none — bell fallback | bell from a process matching `@agent_notify_bell_procs` → `!` |

Restart running agents after installing — they read config at startup.

## Options

Set in `.tmux.conf` before the plugin loads:

| Option | Default | Meaning |
|---|---|---|
| `@agent_notify_icon_permission` | `⏸` | icon per state; same pattern for `_question` (`⏸`), `_done` (`✔`), `_error` (`✖`), `_bell` (`!`) |
| `@agent_notify_color_permission` | `yellow` | color per state; `_question` `yellow`, `_done` `green`, `_error` `red`, `_bell` `yellow` |
| `@agent_notify_jump_key` | `a` | `prefix + <key>` jumps to the next flagged window |
| `@agent_notify_bell_procs` | `agy antigravity` | space-separated process names for the bell fallback |

## Behavior

- The window you are looking at is not flagged, except errors.
- Two agents in one window: last writer wins.
- A tmux server restart clears all state.

## License

[MIT](LICENSE)
