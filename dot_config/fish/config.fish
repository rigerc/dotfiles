if status is-interactive
    set fish_tmux_autostart true
    fastfetch
end

# shared .env file zsh/fish
function setenv
    if [ $argv[1] = PATH ]
        # Replace colons and spaces with newlines
        set -gx PATH (echo $argv[2] | tr ': ' \n)
    else
        set -gx $argv
    end
 end

source ~/.env

# aliases
source ~/.aliases

# starship prompt
starship init fish | source