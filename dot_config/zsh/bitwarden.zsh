# Bitwarden session management functions managed by chezmoi
# Place at ~/.local/share/chezmoi/dot_config/zsh/bitwarden.zsh

# Only load if Bitwarden CLI is available
if command -v bw &> /dev/null; then

  # Session management
  bw_login() {
    echo "Logging into Bitwarden via SSO..."
    bw login --sso
    if [[ $? -eq 0 ]]; then
      echo "SSO login initiated. Please complete the authentication in your browser."
      echo "After completing SSO, run 'bwu' to unlock your vault."
    else
      echo "SSO login failed. Please check your connection and try again."
      return 1
    fi
  }

  bw_login_with_session() {
    echo "Logging into Bitwarden via SSO and unlocking..."
    bw login --sso
    if [[ $? -eq 0 ]]; then
      local session=$(bw unlock --raw 2>/dev/null)
      if [[ $? -eq 0 ]]; then
        export BW_SESSION="$session"
        bw_set_lock_timer
        echo "SSO login successful and vault unlocked."
      else
        echo "Failed to unlock vault after SSO login."
        return 1
      fi
    fi
  }

  bw_unlock() {
    echo "Unlocking Bitwarden vault..."
    local session=$(bw unlock --raw 2>/dev/null)
    if [[ $? -eq 0 ]]; then
      export BW_SESSION="$session"
      echo "Vault unlocked successfully."
      echo "Session token set in BW_SESSION environment variable."
    else
      echo "Failed to unlock vault. Please check your master password."
      return 1
    fi
  }

  bw_locked() {
    local status=$(bw status --session "$BW_SESSION" 2>/dev/null | jq -r '.status' 2>/dev/null)
    [[ "$status" == "locked" ]]
  }

  bw_session() {
    if [[ -z "$BW_SESSION" ]] || bw_locked; then
      echo "Vault is locked or no session. Unlocking..."
      bw_unlock
    fi
    echo "$BW_SESSION"
  }

  bw_logout() {
    if [[ -n "$BW_SESSION" ]]; then
      bw logout --session "$BW_SESSION" 2>/dev/null
      unset BW_SESSION
      echo "Logged out successfully."
    else
      echo "No active session to logout from."
    fi
  }

  # Enhanced password operations
  bw_copy() {
    bw_session
    local item_name="$1"
    if [[ -z "$item_name" ]]; then
      echo "Usage: bw_copy <item_name>"
      return 1
    fi

    local password=$(bw get password "$item_name" --session "$BW_SESSION" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
      echo "$password" | pbcopy 2>/dev/null || echo "$password" | xclip -selection clipboard 2>/dev/null || echo "$password"
      echo "Password copied to clipboard."
      # Clear clipboard after 30 seconds if pbcopy/xclip is available
      if command -v pbcopy &> /dev/null || command -v xclip &> /dev/null; then
        (sleep 30 && echo "" | pbcopy 2>/dev/null || echo "" | xclip -selection clipboard 2>/dev/null) &
      fi
    else
      echo "Failed to retrieve password for '$item_name'"
      return 1
    fi
  }

  bw_generate() {
    local length="${1:-16}"
    local special="${2:-true}"

    bw_session
    local password=$(bw generate --length "$length" --special "$special" --session "$BW_SESSION" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
      echo "$password"
      echo "$password" | pbcopy 2>/dev/null || echo "$password" | xclip -selection clipboard 2>/dev/null || echo "$password"
      echo "Generated password copied to clipboard."
    else
      echo "Failed to generate password"
      return 1
    fi
  }

  # Quick add password
  bw_add_password() {
    bw_session
    local name="$1"
    local username="$2"
    local password="$3"

    if [[ -z "$name" || -z "$username" || -z "$password" ]]; then
      echo "Usage: bw_add_password <name> <username> <password>"
      return 1
    fi

    bw create item --session "$BW_SESSION" << EOF
{
  "name": "$name",
  "login": {
    "username": "$username",
    "password": "$password"
  }
}
EOF
    if [[ $? -eq 0 ]]; then
      echo "Password added successfully."
      bw sync --session "$BW_SESSION" > /dev/null
    fi
  }

  # Status check with more info
  bw_status() {
    bw_session
    local status_output=$(bw status --session "$BW_SESSION" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
      echo "$status_output" | jq
    else
      echo "Unable to get status. Try unlocking the vault with 'bwu'."
    fi
  }

  # Sync vault
  bw_sync_now() {
    bw_session
    bw sync --session "$BW_SESSION"
    if [[ $? -eq 0 ]]; then
      echo "Vault synced successfully."
    else
      echo "Failed to sync vault."
      return 1
    fi
  }

  # FZF integration functions
  if command -v fzf &> /dev/null; then
    bw_fzf() {
      bw_session
      local item=$(bw list items --session "$BW_SESSION" | jq -r '.[] | "\(.name) | \(.login.username // "no username")"' | fzf --height 40% --reverse --prompt="Select item: " --delimiter='|' --with-nth=1)
      if [[ -n "$item" ]]; then
        local item_name=$(echo "$item" | cut -d'|' -f1 | xargs)
        echo "$item_name"
      fi
    }

    bw_copy_fzf() {
      local item_name=$(bw_fzf)
      if [[ -n "$item_name" ]]; then
        bw_copy "$item_name"
      fi
    }

    bw_edit_fzf() {
      local item_name=$(bw_fzf)
      if [[ -n "$item_name" ]]; then
        bwe "$item_name"
      fi
    }

    bw_totp_fzf() {
      bw_session
      local item=$(bw list items --session "$BW_SESSION" | jq -r '.[] | select(.login.totp != null) | "\(.name) | \(.login.username // "no username")"' | fzf --height 40% --reverse --prompt="Select TOTP item: " --delimiter='|' --with-nth=1)
      if [[ -n "$item" ]]; then
        local item_name=$(echo "$item" | cut -d'|' -f1 | xargs)
        local totp=$(bw get totp "$item_name" --session "$BW_SESSION" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
          echo "$totp"
          echo "$totp" | pbcopy 2>/dev/null || echo "$totp" | xclip -selection clipboard 2>/dev/null || echo "$totp"
          echo "TOTP code copied to clipboard."
        else
          echo "Failed to get TOTP code for '$item_name'"
        fi
      fi
    }

    bw_list_fzf() {
      bw_session
      local item=$(bw list items --session "$BW_SESSION" | jq -r '.[] | "\(.name) | \(.login.username // "no username") | \(.id)"' | fzf --height 40% --reverse --prompt="View item details: " --delimiter='|' --with-nth=1,2)
      if [[ -n "$item" ]]; then
        local item_id=$(echo "$item" | cut -d'|' -f3 | xargs)
        bw get item "$item_id" --session "$BW_SESSION" | jq
      fi
    }
  fi

  # Auto-lock timer (default 10 minutes)
  BW_AUTO_LOCK_TIMEOUT="${BW_AUTO_LOCK_TIMEOUT:-600}"
  BW_LOCK_TIME=""

  bw_set_lock_timer() {
    BW_LOCK_TIME=$(($(date +%s) + BW_AUTO_LOCK_TIMEOUT))
  }

  bw_check_auto_lock() {
    if [[ -n "$BW_SESSION" && -n "$BW_LOCK_TIME" ]]; then
      local current_time=$(date +%s)
      if [[ $current_time -ge $BW_LOCK_TIME ]]; then
        echo "Auto-locking Bitwarden vault (timeout reached)"
        bw lock --session "$BW_SESSION" > /dev/null 2>&1
        unset BW_SESSION
        unset BW_LOCK_TIME
      fi
    fi
  }

  # Set lock timer on successful unlock
  bw_unlock_with_timer() {
    bw_unlock
    if [[ $? -eq 0 ]]; then
      bw_set_lock_timer
    fi
  }

  # Override original unlock function with timer
  alias bwu="bw_unlock_with_timer"

  # Manual lock function
  bw_lock() {
    if [[ -n "$BW_SESSION" ]]; then
      bw lock --session "$BW_SESSION"
      unset BW_SESSION
      unset BW_LOCK_TIME
      echo "Vault locked manually."
    else
      echo "No active session to lock."
    fi
  }

  # Security enhancements for clipboard
  bw_copy_secure() {
    bw_copy "$@"
    # Set a shorter clipboard timeout for sensitive passwords
    if command -v pbcopy &> /dev/null || command -v xclip &> /dev/null; then
      (sleep 15 && echo "" | pbcopy 2>/dev/null || echo "" | xclip -selection clipboard 2>/dev/null) &
      echo "Clipboard will be cleared in 15 seconds."
    fi
  }

  # Override original copy function
  alias bwc="bw_copy_secure"

  # Check auto-lock periodically (hook into prompt)
  autoload -U add-zsh-hook
  add-zsh-hook precmd bw_check_auto_lock

  # Cleanup on shell exit
  bw_cleanup() {
    if [[ -n "$BW_SESSION" ]]; then
      bw lock --session "$BW_SESSION" > /dev/null 2>&1
      unset BW_SESSION
      unset BW_LOCK_TIME
    fi
  }

  trap bw_cleanup EXIT

  # Auto-unlock on shell startup if session exists
  if [[ -n "$BW_SESSION" ]]; then
    if ! bw_locked 2>/dev/null; then
      echo "Bitwarden vault is unlocked."
      bw_set_lock_timer
    else
      unset BW_SESSION
    fi
  fi

fi