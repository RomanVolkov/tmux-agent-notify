
get_tmux_option() {
	local option="$1"
	local default="$2"
	local value
	value="$(tmux show-option -gqv "$option")"
	if [ -n "$value" ]; then
		printf '%s' "$value"
	else
		printf '%s' "$default"
	fi
}
