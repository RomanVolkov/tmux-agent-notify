#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/scripts/helpers.sh"

build_state_snippet() {
	local icon_permission icon_question icon_done icon_error icon_bell
	local color_permission color_question color_done color_error color_bell
	icon_permission="$(get_tmux_option @agent_notify_icon_permission '⏸')"
	icon_question="$(get_tmux_option @agent_notify_icon_question '⏸')"
	icon_done="$(get_tmux_option @agent_notify_icon_done '✔')"
	icon_error="$(get_tmux_option @agent_notify_icon_error '✖')"
	icon_bell="$(get_tmux_option @agent_notify_icon_bell '!')"
	color_permission="$(get_tmux_option @agent_notify_color_permission 'yellow')"
	color_question="$(get_tmux_option @agent_notify_color_question 'yellow')"
	color_done="$(get_tmux_option @agent_notify_color_done 'green')"
	color_error="$(get_tmux_option @agent_notify_color_error 'red')"
	color_bell="$(get_tmux_option @agent_notify_color_bell 'yellow')"

	printf '%s' "#{?#{@agent_state}, #{?#{==:#{@agent_state},done},#[fg=${color_done}]${icon_done},#{?#{==:#{@agent_state},error},#[fg=${color_error}]${icon_error},#{?#{==:#{@agent_state},bell},#[fg=${color_bell}]${icon_bell},#{?#{==:#{@agent_state},question},#[fg=${color_question}]${icon_question},#[fg=${color_permission}]${icon_permission}}}}}#[default],}"
}

wrap_format() {
	local format_option="$1" snippet="$2"
	local stash_option="@agent_notify_orig_${format_option//-/_}"
	local base current
	current="$(tmux show-option -gqv "$format_option")"
	case "$current" in
	*@agent_state*)
		base="$(tmux show-option -gqv "$stash_option")"
		;;
	*)
		base="$current"
		tmux set-option -g "$stash_option" "$base"
		;;
	esac
	tmux set-option -g "$format_option" "${base}${snippet}"
}

main() {
	tmux set-option -g @agent_notify_root "$CURRENT_DIR"
	tmux set-option -g focus-events on
	tmux set-option -g monitor-bell on

	local snippet
	snippet="$(build_state_snippet)"
	wrap_format window-status-format "$snippet"
	wrap_format window-status-current-format "$snippet"

	tmux set-hook -g 'pane-focus-in[37]' 'set-option -uw @agent_state ; set-option -uw @agent_name'

	local jump_key
	jump_key="$(get_tmux_option @agent_notify_jump_key 'a')"
	tmux bind-key "$jump_key" run-shell "$CURRENT_DIR/scripts/jump.sh"

	tmux set-hook -g 'alert-bell[37]' "run-shell '$CURRENT_DIR/scripts/on-bell.sh #{window_id}'"
}

main
