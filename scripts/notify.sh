#!/usr/bin/env bash
set -euo pipefail

agent="${1:?usage: notify.sh <agent> <state> [pane]}"
state="${2:?usage: notify.sh <agent> <state> [pane]}"
# The OpenCode v2 plugin runs inside the shared server, so it passes the pane
# it resolved for the session. Fall back to TMUX_PANE for direct callers.
pane="${3:-${TMUX_PANE:-}}"

[ -n "$pane" ] || exit 0
win="$(tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null)" || exit 0

if [ "$state" = "busy" ]; then
	tmux set-option -uw -t "$win" @agent_state 2>/dev/null || true
	tmux set-option -uw -t "$win" @agent_name 2>/dev/null || true
	tmux refresh-client -S 2>/dev/null || true
	exit 0
fi

if [ "$state" != "error" ]; then
	visible="$(tmux display-message -p -t "$pane" '#{?#{&&:#{window_active},#{session_attached}},1,0}')"
	[ "$visible" = "1" ] && exit 0
fi

tmux set-option -w -t "$win" @agent_state "$state"
tmux set-option -w -t "$win" @agent_name "$agent"
tmux refresh-client -S 2>/dev/null || true
