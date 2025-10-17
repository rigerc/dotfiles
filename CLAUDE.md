# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed with Chezmoi, designed for cross-platform development environment setup (macOS and Linux). The repository includes shell configuration, development tools, and application settings.

## Key Commands

### Chezmoi Management
```bash
# Initialize and apply dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply rigerc

# Apply changes after modifying files
chezmoi apply

# Check status of managed files
chezmoi status

# Edit managed files (opens in configured EDITOR)
chezmoi edit <file>

# Add new file to management
chezmoi add <file>
```

### Package Management
```bash
# Update all Homebrew packages and cleanup
brew-update

# Update global npm packages
npm-update

# Install/update all packages defined in .chezmoidata/packages.yaml
# This happens automatically when chezmoi detects changes to packages.yaml
```

### Development Tools
```bash
# Git operations with aliases
gst                 # git status
glog                # git log --oneline --graph --decorate --all
gco <branch>        # git checkout
gadd                # git add .
gcm "message"       # git commit -m "message"
gp                  # git push
gl                  # git pull
gpl                 # git pull --rebase
lg                  # lazygit (TUI git client)

# Tmux operations
t                   # tmux
ta                  # tmux attach
tn                  # tmux new-session
tl                  # tmux list-sessions
tk                  # tmux kill-session

# Navigation with zoxide + fzf
z                   # zoxide (smart cd)
zif                 # zoxide with fzf interactive selection
zif_preview         # zoxide with fzf and directory preview

# File operations
ls                  # eza (modern ls with icons)
ll                  # eza -la --icons --octal-permissions
l                   # eza -bGF --header --git
la                  # eza --long --all --group
```

## Architecture and Structure

### Chezmoi Integration
- Uses Chezmoi for dotfile management with templates
- Configuration stored in `.chezmoidata/packages.yaml` for package lists
- `.chezmoiignore` excludes Claude-related files from management
- Supports automatic package installation when `packages.yaml` changes

### Shell Environment (Zsh)
- **Plugin Management**: Uses Zinit for fast plugin loading
- **Key Plugins**:
  - `fast-syntax-highlighting`: Syntax highlighting
  - `zsh-autosuggestions`: Command suggestions based on history
  - `fzf-tab`: Fuzzy completion with tab support
  - `starship`: Custom prompt configuration
  - `zoxide`: Smart directory navigation
- **Configuration Files**:
  - `dot_zshrc`: Main Zsh configuration with plugin initialization
  - `dot_config/zsh/aliases.zsh`: Comprehensive alias definitions
  - `dot_config/zsh/tmux.zsh`: Auto-start tmux configuration

### Terminal Multiplexer (Tmux)
- **Plugin Management**: Uses TPM for plugin management
- **Key Plugins**: vim-tmux-navigator, tmux-yank, tmux-resurrect
- **Features**: Auto-restore sessions, true color support, automatic window renaming

### Editor Configuration
- **Primary Editor**: Neovim with LazyVim bootstrap (external repo)
- **Fallback**: Nano with enhanced configuration
- **Configuration**: `dot_config/nvim/` (LazyVim managed via externals)

### Development Tools
- **Version Control**: Git with enhanced aliases and LazyGit TUI
- **File Search**: ripgrep (rg), fzf for fuzzy finding
- **File Operations**: eza (ls replacement), fd (find replacement), bat (cat replacement)
- **Utilities**: jq (JSON), yq (YAML), htop, zoxide

### Package Management
- **Homebrew**: Primary package manager (macOS and Linux)
- **Package Lists**: Defined in `.chezmoidata/packages.yaml` with categories:
  - Development: Node, Python, Go, Rust
  - Tools: GitHub CLI, lazygit, ripgrep, fzf, etc.
  - Editors: Neovim, nano, micro
  - Shell: zsh, tmux
- **Installation Scripts**:
  - `run_once_01-install-homebrew.sh`: Homebrew installation
  - `run_onchange_99-install-homebrew-packages.sh.tmpl`: Package installation

### Prompt Configuration
- **Starship Prompt**: Custom configuration in `dot_config/starship.toml`
- **Features**: Git status, Python virtual environments, command duration, clean minimal design

### External Repositories
- **Zinit**: Managed via `.chezmoiexternals/zinit.toml`
- **LazyVim**: Managed via `.chezmoiexternals/lazyvim.toml`
- **TPM**: Managed via `.chezmoiexternals/tpm.toml`
- **Fonts**: Managed via `.chezmoiexternals/fonts.toml.tmpl`

## Development Workflow

1. **Initial Setup**: Run the chezmoi init command from README.MD
2. **Making Changes**: Edit files with `chezmoi edit <file>` or modify source files directly
3. **Applying Changes**: Run `chezmoi apply` to update the system
4. **Package Updates**: Modify `.chezmoidata/packages.yaml` and changes will auto-apply
5. **Shell Reload**: Use `reload` alias or `exec zsh` to reload shell configuration

## File Locations

- **Chezmoi Config**: `dot_config/chezmoi/chezmoi.toml`
- **Shell Aliases**: `dot_config/zsh/aliases.zsh`
- **Tmux Config**: `dot_tmux.conf`
- **Starship Prompt**: `dot_config/starship.toml`
- **Neovim Config**: `dot_config/nvim/` (LazyVim external)
- **Package List**: `.chezmoidata/packages.yaml`

## Platform Support

Designed to work on both macOS and Linux with platform-specific handling in installation scripts. Uses XDG Base Directory specification for config organization where possible.