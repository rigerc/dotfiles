if status is-interactive
    #set fish_tmux_autostart true
    fastfetch
end

# aliases
source ~/.aliases

# starship prompt
starship init fish | source