# Tmux integration for Zsh managed by chezmoi
# Place at ~/.local/share/chezmoi/dot_config/zsh/tmux.zsh

# Auto-start tmux on shell launch (only if not already in tmux)
if command -v tmux &> /dev/null; then
    # Don't start tmux if we're already inside a tmux session
    if [[ -z "$TMUX" && -z "$INSIDE_EMACS" && -z "$SSH_TTY" ]]; then
        # Check if we have any existing sessions
        if tmux has-session 2>/dev/null; then
            # If there are existing sessions, attach to the first one or create a new one
            if [[ -n "$1" ]]; then
                # If a session name is provided, attach to it or create it
                tmux new-session -A -s "$1"
            else
                # Otherwise, attach to the most recently used session or create a new one
                tmux attach-session || tmux new-session
            fi
        else
            # If no sessions exist, create a new one
            tmux new-session
        fi
    fi
fi

# Tmux session management functions
tmux-session() {
    if [[ -n "$1" ]]; then
        tmux new-session -d -s "$1" && tmux attach-session -t "$1"
    else
        echo "Usage: tmux-session <session-name>"
    fi
}

tmux-switch() {
    local session
    session=$(tmux list-sessions | fzf --prompt="Switch to session: " | cut -d: -f1)
    if [[ -n "$session" ]]; then
        tmux switch-client -t "$session"
    fi
}

tmux-new-window() {
    if [[ -n "$1" ]]; then
        tmux new-window -n "$1"
    else
        tmux new-window
    fi
}

tmux-select-window() {
    local window
    window=$(tmux list-windows | fzf --prompt="Select window: " | cut -d: -f1)
    if [[ -n "$window" ]]; then
        tmux select-window -t "$window"
    fi
}

# Tmux completion
autoload -Uz add-zsh-hook

# Function to set terminal title to current tmux session/window
tmux-title() {
    if [[ -n "$TMUX" ]]; then
        local session=$(tmux display-message -p '#S')
        local window=$(tmux display-message -p '#W')
        print -Pn "\e]2;$session:$window\a"
    fi
}

# Update title when changing directories or running commands
add-zsh-hook precmd tmux-title
add-zsh-hook preexec tmux-title

# Tmux environment variables
export TMUX_TMPDIR="$TMPDIR"
export TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins"

# Ensure tmux plugins directory exists
if [[ ! -d "$HOME/.tmux/plugins" ]]; then
    mkdir -p "$HOME/.tmux/plugins"
fi