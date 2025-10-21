if status is-interactive; and begin
    set fish_tmux_autostart true
end


alias ls='eza --all --long --group --group-directories-first --icons --header --time-style long-iso'
alias tree='eza --tree'
alias cat='bat'
alias grep='rg'
alias please="sudo !!"
alias pacman="sudo pacman --noconfirm"
alias config="cd ~/.config"

starship init fish | source