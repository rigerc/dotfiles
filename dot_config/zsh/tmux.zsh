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