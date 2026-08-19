#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

win="${1:?usage: on-bell.sh <window_id>}"
procs="$(get_tmux_option @agent_notify_bell_procs 'agy antigravity')"

match_pid() {
	local pid="$1" tok proc
	for tok in $(ps -p "$pid" -o command= 2>/dev/null); do
		tok="$(basename "$tok")"
		for proc in $procs; do
			[ "$tok" = "$proc" ] && printf '%s' "$proc" && return 0
		done
	done
	return 1
}

while read -r pane_id pane_pid; do
	agent=""
	for pid in "$pane_pid" $(pgrep -P "$pane_pid" 2>/dev/null || true); do
		if agent="$(match_pid "$pid")"; then
			break
		fi
		agent=""
	done
	if [ -n "$agent" ]; then
		TMUX_PANE="$pane_id" exec "$CURRENT_DIR/notify.sh" "$agent" bell
	fi
done < <(tmux list-panes -t "$win" -F '#{pane_id} #{pane_pid}')

exit 0
