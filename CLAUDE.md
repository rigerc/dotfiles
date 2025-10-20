# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository managed with [Chezmoi](https://www.chezmoi.io/), a dotfile management system that handles configuration across multiple machines while supporting templating and secrets management.

## Installation & Setup

### Initial Setup
```bash
# Install and apply dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply rigerc
```

### Common Commands
```bash
# Apply all dotfiles
chezmoi apply

# Apply specific files
chezmoi apply ~/.zshrc

# Edit source files (opens in $EDITOR)
chezmoi edit ~/.zshrc

# Check what would change without applying
chezmoi diff

# Update from remote and apply changes
chezmoi update && chezmoi apply

# Add new file to management
chezmoi add ~/.config/some-app/config

# Remove file from management (keeps actual file)
chezmoi forget ~/.config/some-app/config
```

## Architecture

### Directory Structure
- `dot_*` - Files that will be symlinked to home directory (dot_ becomes .)
- `.chezmoi.toml.tmpl` - Configuration template with prompts for user data
- `.chezmoiscripts/` - Scripts that run during chezmoi operations
- `dot_config/` - Configuration files for ~/.config/
- `.chezmoiignore` - Files to ignore in chezmoi management

### Key Components

#### Configuration Management
- Uses Chezmoi templates (`.tmpl` files) for dynamic configuration
- Integrates with Bitwarden for secrets management via `bitwardenFields`
- Supports different data per machine while sharing most configurations

#### Shell Environment (Zsh + Zinit)
- **Zinit Plugin Manager**: Fast, turbo-charged plugin loading
- **Key Plugins**:
  - `zsh-autosuggestions` - Command suggestions based on history
  - `fast-syntax-highlighting` - Syntax highlighting
  - `fzf-tab` - Fuzzy completion with tab
  - `starship` - Custom prompt
  - `zoxide` - Smart directory jumping
- **Custom Functions**: Interactive directory jumping with fzf integration

#### Terminal Multiplexer (Tmux)
- **TPM Plugin Manager** for package management
- **Key Plugins**: tmux-sensible, tmux-yank, vim-tmux-navigator, tmux-resurrect, catppuccin theme
- **Auto-restore**: Sessions automatically restored on start
- **Navigation**: Vi-style pane navigation and Vim integration

#### Development Tools
- **Modern Replacements**: eza (ls), bat (cat), ripgrep (grep)
- **Git**: Enhanced aliases and lazygit integration
- **Editor**: Neovim as default vim/vi replacement

### Script System

#### Chezmoi Scripts (.chezmoiscripts/)
- **.common.sh**: Shared utilities, logging, and Homebrew management functions
- **run_once_00-install-homebrew.sh**: Automated Homebrew installation
- **run_onchange_01_install_homebrew_packages.sh.tmpl**: Package installation via Brewfile
- **Scripts execute** automatically during `chezmoi apply` based on their filename pattern

#### Script Naming Conventions
- `run_once_*` - Execute only once per machine
- `run_onchange_*` - Execute when specified files change
- `run_onchange_before_*` - Execute before file changes
- `run_once_after_*` - Execute after initial setup

### Data & Templates
- **User Data**: GitHub username/email configured via prompts during init
- **Secrets**: API keys retrieved from Bitwarden using template functions
- **Cross-platform**: Supports Linux (WSL), macOS with platform-specific handling

## Platform Support
- Primary: Linux (WSL2)
- Secondary: macOS (Intel/Apple Silicon)
- Homebrew package manager handles cross-platform package installation
- Zsh and Tmux configurations work consistently across platforms