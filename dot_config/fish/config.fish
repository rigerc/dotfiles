if status is-interactive
    #set fish_tmux_autostart true
    atuin init fish | source
end

# env
source ~/.env

# aliases
source ~/.aliases

# alman 
alman init fish | source

#carapace
set -Ux CARAPACE_BRIDGES 'zsh,fish,bash,inshellisense' # optional
carapace _carapace | source

# starship prompt
# starship init fish | source

# oh my posh prompt
oh-my-posh init fish --config powerlevel10k_lean | source

# zoxide & fish
zoxide init fish | source