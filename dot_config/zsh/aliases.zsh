# Zsh aliases managed by chezmoi
# Place at ~/.local/share/chezmoi/dot_config/zsh/aliases.zsh

# File and directory operations
alias mkdir="mkdir -p"
alias cp="cp -i"
alias mv="mv -i"
alias rm="rm -i"
alias du="du -h"
alias df="df -h"
alias cat="bat"
alias grep="ripgrep"
alias z="zoxide"

# Development
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias python="python3"
alias py="python3"
alias pip="pip3"

# Network and system
alias ping="ping -c 5"
alias myip="curl -s https://api.ipify.org"
alias ports="netstat -tulan"
alias ps="ps aux"
alias psg="ps aux | grep"
alias kill="kill -9"

# Package management
alias brew-update="brew update && brew upgrade && brew cleanup"
alias npm-update="npm update -g"

# Directory navigation
alias config="cd ~/.config"

# Utility aliases
alias c="clear"
alias h="history"
alias path="echo $PATH | tr ':' '\n'"
alias fzf-preview="fzf --preview 'bat --color=always {}'"
alias please="sudo !!"
alias reload="exec zsh"

# Tmux aliases (if using tmux)
alias t="tmux"