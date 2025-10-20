# Tmux integration for Zsh managed by chezmoi

# Auto-start tmux on shell launch (only if not already in tmux)
if command -v tmux &> /dev/null && [[ -z "$TMUX" && -z "$INSIDE_EMACS" && -z "$SSH_TTY" ]]; then
    # Try to attach to existing session, or create new one if none exist
    tmux attach-session -t default 2>/dev/null || tmux new-session -s default
fi