# Keep PATH changes process-local rather than writing universal variables.
fish_add_path --global --path $HOME/.local/bin $HOME/.atuin/bin

if not status is-interactive
    return
end

set -g fish_greeting

# Ctrl-R searches Atuin; the Up arrow keeps Fish's normal history behavior.
if command -sq atuin
    atuin init fish --disable-up-arrow | source
end

dotfiles_remote_session
