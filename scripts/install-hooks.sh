#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPTS_DIR")"

CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
CODEX_CONFIG="${CODEX_CONFIG:-$HOME/.codex/config.toml}"
OPENCODE_PLUGIN_DIR="${OPENCODE_PLUGIN_DIR:-$HOME/.config/opencode/plugin}"

CLAUDE_CMD_PREFIX='r="$(tmux show-option -gqv @agent_notify_root 2>/dev/null)"; [ -z "$r" ] || "$r/scripts/notify-claude.sh" '

mode="print"
[ "${1:-}" = "--apply" ] && mode="apply"

claude_snippet() {
	cat <<'EOF'
{
  "hooks": {
    "Notification": [{"hooks": [{"type": "command", "command": "r=\"$(tmux show-option -gqv @agent_notify_root 2>/dev/null)\"; [ -z \"$r\" ] || \"$r/scripts/notify-claude.sh\" Notification"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "r=\"$(tmux show-option -gqv @agent_notify_root 2>/dev/null)\"; [ -z \"$r\" ] || \"$r/scripts/notify-claude.sh\" Stop"}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "r=\"$(tmux show-option -gqv @agent_notify_root 2>/dev/null)\"; [ -z \"$r\" ] || \"$r/scripts/notify-claude.sh\" UserPromptSubmit"}]}]
  }
}
EOF
}

apply_claude() {
	if ! command -v jq >/dev/null 2>&1; then
		echo "claude: jq required for --apply; add manually:" >&2
		claude_snippet
		return 0
	fi
	mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
	[ -f "$CLAUDE_SETTINGS" ] || echo '{}' >"$CLAUDE_SETTINGS"
	if grep -q 'notify-claude.sh' "$CLAUDE_SETTINGS"; then
		echo "claude: already installed ($CLAUDE_SETTINGS)"
		return 0
	fi
	cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak"
	jq --arg pre "$CLAUDE_CMD_PREFIX" '
		def ensure(ev):
			.hooks[ev] = ((.hooks[ev] // []) + [{"hooks": [{"type": "command", "command": ($pre + ev)}]}]);
		.hooks //= {} | ensure("Notification") | ensure("Stop") | ensure("UserPromptSubmit")
	' "$CLAUDE_SETTINGS.bak" >"$CLAUDE_SETTINGS"
	echo "claude: hooks added to $CLAUDE_SETTINGS (backup: $CLAUDE_SETTINGS.bak)"
}

codex_snippet() {
	printf 'notify = ["%s/notify-codex.sh"]\n' "$SCRIPTS_DIR"
}

apply_codex() {
	mkdir -p "$(dirname "$CODEX_CONFIG")"
	touch "$CODEX_CONFIG"
	if grep -q 'notify-codex.sh' "$CODEX_CONFIG"; then
		echo "codex: already installed ($CODEX_CONFIG)"
		return 0
	fi
	if grep -q '^[[:space:]]*notify[[:space:]]*=' "$CODEX_CONFIG"; then
		echo "codex: a different 'notify' setting exists in $CODEX_CONFIG — merge manually:" >&2
		codex_snippet
		return 0
	fi
	cp "$CODEX_CONFIG" "$CODEX_CONFIG.bak"
	{
		codex_snippet
		cat "$CODEX_CONFIG.bak"
	} >"$CODEX_CONFIG"
	echo "codex: notify added to $CODEX_CONFIG (backup: $CODEX_CONFIG.bak)"
}

apply_opencode() {
	mkdir -p "$OPENCODE_PLUGIN_DIR"
	cp "$PLUGIN_DIR/opencode-plugin/agent-notify.js" "$OPENCODE_PLUGIN_DIR/agent-notify.js"
	echo "opencode: plugin copied into $OPENCODE_PLUGIN_DIR"
}

if [ "$mode" = "print" ]; then
	echo "# Claude Code — merge into $CLAUDE_SETTINGS:"
	claude_snippet
	echo
	echo "# Codex — add to $CODEX_CONFIG (top level; codex spawns it without a shell, so the path must be absolute):"
	codex_snippet
	echo
	echo "# OpenCode — copy the plugin (it locates the scripts via the tmux option @agent_notify_root):"
	echo "cp $PLUGIN_DIR/opencode-plugin/agent-notify.js $OPENCODE_PLUGIN_DIR/agent-notify.js"
	echo
	echo "# Antigravity/others: no setup — bell fallback (see @agent_notify_bell_procs)."
	echo "# Run with --apply to patch these files automatically."
else
	apply_claude
	apply_codex
	apply_opencode
fi
