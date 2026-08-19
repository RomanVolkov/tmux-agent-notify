#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
event="${1:?usage: notify-claude.sh <Notification|Stop|UserPromptSubmit>}"

state=""
case "$event" in
Stop) state="done" ;;
UserPromptSubmit) state="busy" ;;
Notification)
	payload="$(cat 2>/dev/null || true)"
	if command -v jq >/dev/null 2>&1; then
		msg="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null || true)"
	else
		msg="$payload"
	fi
	case "$msg" in
	*[Pp]ermission* | *[Aa]pproval*) state="permission" ;;
	*) state="question" ;;
	esac
	;;
*) exit 0 ;;
esac

exec "$CURRENT_DIR/notify.sh" claude "$state"
