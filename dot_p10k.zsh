# Powerlevel10k configuration managed by chezmoi
# Place at ~/.local/share/chezmoi/dot_p10k.zsh

# Instant prompt - should stay close to the top of ~/.zshrc
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Prompt segments - customize what's shown
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  os_icon
  dir
  git
  newline
  prompt_char
)

typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  command_execution_time
  background_jobs
  time
)

# Directory truncation
typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY="truncate_from_right"

# Git status styling
typeset -g POWERLEVEL9K_GIT_BRANCH_ICON=" "
typeset -g POWERLEVEL9K_GIT_CLEAN_ICON="✓"
typeset -g POWERLEVEL9K_GIT_DIRTY_ICON="✕"

# Time format
typeset -g POWERLEVEL9K_TIME_FORMAT="%D{%H:%M}"

# Prompt character
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_CONTENT_EXPANSION='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VICMD_CONTENT_EXPANSION='❮'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VICMD_CONTENT_EXPANSION='❮'

# Transient prompt - show simple prompt for previous commands
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT_EXPANSION='❯ '