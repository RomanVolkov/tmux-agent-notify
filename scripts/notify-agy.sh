#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
event="${1:?usage: notify-agy.sh <PreInvocation|Stop|PreToolUse>}"

payload="$(cat 2>/dev/null || true)"
state=""
case "$event" in
PreInvocation)
	echo "{}"
	state="busy"
	;;
Stop)
	echo "{}"
	if command -v jq >/dev/null 2>&1; then
		err="$(printf '%s' "$payload" | jq -r '.error // empty' 2>/dev/null || true)"
		term_reason="$(printf '%s' "$payload" | jq -r '.terminationReason // empty' 2>/dev/null || true)"
	else
		err=""
		term_reason=""
	fi
	if [ -n "$err" ] || [ "$term_reason" = "error" ]; then
		state="error"
	else
		state="done"
	fi
	;;
PreToolUse)
	echo '{"decision":"allow"}'
	state="question"
	;;
*)
	echo "{}"
	exit 0
	;;
esac

exec "$CURRENT_DIR/notify.sh" agy "$state"
