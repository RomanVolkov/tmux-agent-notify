#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ "$#" -ge 1 ] || exit 0
payload="${!#}"

if command -v jq >/dev/null 2>&1; then
	type="$(printf '%s' "$payload" | jq -r '.type // empty' 2>/dev/null || true)"
else
	type="$(printf '%s' "$payload" | sed -n 's/.*"type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi

case "$type" in
agent-turn-complete) state="done" ;;
*approval* | *permission*) state="permission" ;;
*error*) state="error" ;;
*) exit 0 ;;
esac

exec "$CURRENT_DIR/notify.sh" codex "$state"
