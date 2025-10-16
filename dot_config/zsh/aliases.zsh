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
alias ta="tmux attach"
alias tl="tmux list-sessions"
alias tn="tmux new-session"
alias tk="tmux kill-session"
alias ts="tmux switch-client"
alias tkill="tmux kill-server"

# Git aliases (enhanced)
alias glog="git log --oneline --graph --decorate --all"
alias gst="git status"
alias gco="git checkout"
alias gbr="git branch"
alias gadd="git add ."
alias gcm="git commit -m"
alias gp="git push"
alias gl="git pull"
alias gpl="git pull --rebase"
alias gpp="git pull --rebase && git push"
alias gd="git diff"
alias gds="git diff --stat"
alias gdc="git diff --cached"
alias grs="git restore"
alias grst="git restore --staged"
alias greset="git reset"
alias gclean="git clean -fd"
alias gsync="git fetch --all --prune && git pull --rebase"

# Lazygit alias
alias lg="lazygit"