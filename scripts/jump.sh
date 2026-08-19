#!/usr/bin/env bash
set -euo pipefail

cur="$(tmux display-message -p '#{window_index}')"

flagged=()
while read -r idx state; do
	[ -n "${state:-}" ] && flagged+=("$idx")
done < <(tmux list-windows -F '#{window_index} #{@agent_state}')

if [ ${#flagged[@]} -eq 0 ]; then
	tmux display-message "no agents waiting"
	exit 0
fi

next=""
for idx in "${flagged[@]}"; do
	if [ "$idx" -gt "$cur" ]; then
		next="$idx"
		break
	fi
done
[ -n "$next" ] || next="${flagged[0]}"

tmux select-window -t ":$next"
