if status is-interactive
    #set fish_tmux_autostart true
    fastfetch
end

# env
source ~/.env

# aliases
source ~/.aliases

# starship prompt
# starship init fish | source

# oh my posh prompt
oh-my-posh init fish --config powerlevel10k_lean | source

# zoxide & fish
zoxide init fish | source