# Personal Dotfiles Repository

A comprehensive dotfiles setup managed with [Chezmoi](https://www.chezmoi.io/), featuring a modern development environment with Zsh, Tmux, and various productivity tools.

## Quick Start

```bash
# WSL Setup
Run pwsh/install_wsl/Install-WSLArchLinux.ps1 to setup WSL installation.

# Chezmoi Installation
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply rigerc
```

## Configuration Files Overview

### Shell Configuration (Zsh)

#### `dot_zshrc` - Main Zsh Configuration
**Purpose**: Core Zsh shell setup with modern plugin management
**Key Changes**:
- Integrates Homebrew environment
- Sets up optimized history configuration (10,000 entries, shared history)
- Installs and configures Zinit plugin manager
- Loads plugins: fast-syntax-highlighting, zsh-autosuggestions, fzf-tab, starship, zoxide
- Configures modern replacements: `eza` for `ls`, `bat` for `cat`, `rg` for `grep`
- Sets up interactive directory jumping with `zif` and `zif_preview` functions

#### `dot_zshenv.tmpl` - Environment Variables
**Purpose**: Sets up shell environment and PATH configuration
**Key Changes**:
- Configures editors: `EDITOR="micro"`, `VISUAL="nvim"`
- Sets UTF-8 locale settings
- Adds development tools to PATH (`~/.local/bin`, `~/.cargo/bin`, `~/.go/bin`)
- Exports API keys from Bitwarden (OPENROUTER_API_KEY, ZAI_API_KEY, GITHUB_TOKEN)
- Configures FZF settings and Git pager (delta)

#### `dot_config/zsh/aliases.zsh` - Command Aliases
**Purpose**: Comprehensive alias collection for productivity
**Key Changes**:
- File operations: safer `cp`, `mv`, `rm` with confirmation prompts
- Development: `vim/nvim` aliases, Python shortcuts
- Modern tool replacements: `cat → bat`, `grep → rg`, `ls → eza`
- Git aliases (35+ shortcuts): `glog`, `gst`, `gco`, `gcm`, `gpull`, `gpush`
- Tmux aliases: `t`, `ta`, `tl`, `tn`, `tk`
- System utilities: `myip`, `ports`, `psg`, `please`

#### `dot_config/zsh/tmux.zsh` - Tmux Auto-start
**Purpose**: Automatically starts Tmux sessions
**Key Changes**:
- Auto-attaches to existing 'default' session or creates new one
- Only runs in interactive shells, not in SSH or Emacs

### Terminal Multiplexer

#### `dot_tmux.conf` - Tmux Configuration
**Purpose**: Advanced Tmux setup with productivity plugins
**Key Changes**:
- Enables mouse support and true colors
- Vi-style key bindings for panes and copy mode
- Custom splits: `|` for horizontal, `-` for vertical
- Loads TPM plugins: tmux-sensible, tmux-yank, vim-tmux-navigator, tmux-resurrect
- Catppuccin theme integration
- Auto-saves sessions every 15 minutes with tmux-continuum
- Automatic session restoration on start

### Terminal Emulator

#### `dot_config/alacritty/alacritty.toml` - Alacritty Terminal
**Purpose**: Modern GPU-accelerated terminal configuration
**Key Changes**:
- Configured for WSL integration
- Uses Iosevka Nerd Font (12pt)
- 90% opacity with blur effects
- Monokai Charcoal theme import
- Block cursor with blinking

### Version Control

#### `dot_gitconfig.tmpl` - Git Configuration
**Purpose**: Personalized Git settings with template variables
**Key Changes**:
- Sets user name and email from prompted data
- Configures GitHub username
- Sets nano as default editor
- Uses `main` as default branch
- Includes external aliases file

### Shell Prompt

#### `dot_config/starship.toml` - Starship Prompt
**Purpose**: Custom minimal prompt with Git integration
**Key Changes**:
- Clean format with username, hostname, directory
- Git branch and status indicators with custom symbols
- Command duration timing
- Python virtual environment display
- Distinct characters for different modes (❯, ❮)

### Backup Shell

#### `dot_bashrc` - Bash Configuration
**Purpose**: Basic Bash setup for fallback scenarios
**Key Changes**:
- Color support for `ls` and `grep`
- Simple PS1 prompt
- Homebrew environment integration

#### `dot_zprofile` - Zsh Profile
**Purpose**: Login shell configuration
**Key Changes**:
- Currently minimal with commented Homebrew integration

### Chezmoi Configuration

#### `.chezmoi.toml.tmpl` - Chezmoi Settings
**Purpose**: Template configuration with secrets management
**Key Changes**:
- Interactive prompts for GitHub username and email
- Bitwarden integration for API keys (OPENROUTER_API_KEY, GITHUB_TOKEN, ZAI_API_KEY)
- Configures temporary directory
- Template data structure for dynamic configuration

### Installation Scripts

#### `.chezmoiscripts/common.sh` - Shared Utilities
**Purpose**: Common functions for all Chezmoi scripts
**Key Changes**:
- Color-coded logging system (info, success, warning, error)
- Error handling with line number tracking
- Homebrew detection and loading functions
- Safe file operations with directory creation

#### `.chezmoiscripts/run_once_00-install-homebrew.sh` - Homebrew Installer
**Purpose**: Automated Homebrew installation
**Key Changes**:
- Detects existing Homebrew installations
- Installs Homebrew if not found
- Updates and configures permissions
- Cross-platform support (Linux and macOS)

#### `.chezmoiscripts/run_onchange_01_install_homebrew_packages.sh.tmpl` - Package Management
**Purpose**: Installs packages from Brewfile when changed
**Key Changes**:
- Template-based package installation
- Runs when Brewfile is modified
- Handles dependencies via Homebrew

### External Integrations

#### `.chezmoiexternals/` - External Resources
**Purpose**: Manages external GitHub repositories
**Key Changes**:
- **alacritty_themes.toml**: Alacritty theme collection
- **git.toml**: Git aliases and configurations
- **lazyvim.toml**: Neovim configuration
- **tpm.toml**: Tmux Plugin Manager
- **zinit.toml**: Zsh plugin manager

### Development Tools

#### `.chezmoidata/packages.yaml` - Package Definitions
**Purpose**: Defines packages for installation scripts
**Key Changes**:
- Centralized package management
- Platform-specific package handling

#### `dot_config/nano/nanorc` - Nano Editor
**Purpose**: Enhanced Nano configuration
**Key Changes**:
- Improved syntax highlighting
- Better default settings

#### `dot_config/mods/mods.yml` - Mods Configuration
**Purpose**: Configuration for Mods CLI tool
**Key Changes**:
- Custom settings for AI-assisted development

## Key Features

### 🚀 Modern Development Environment
- **Zsh + Zinit**: Fast plugin loading with turbo mode
- **Starship Prompt**: Minimal, informative prompt with Git integration
- **Modern Replacements**: `eza`, `bat`, `ripgrep`, `zoxide`, `fd`

### 🛠️ Productivity Tools
- **Tmux**: Auto-restoring sessions with vim-tmux-navigator
- **FZF Integration**: Tab completion with fuzzy finding
- **Smart Aliases**: 80+ aliases for common operations
- **Git Enhancements**: Lazygit, delta pager, custom aliases

### 🔧 Cross-Platform Support
- **WSL2/Linux**: Primary development environment
- **macOS**: Full support with platform-specific handling
- **Homebrew**: Unified package management across platforms

### 🔐 Security & Secrets
- **Bitwarden Integration**: Secure API key management
- **Template System**: Dynamic configuration without storing secrets
- **Environment Variables**: Secure token handling

### 📦 Automated Setup
- **One-Liner Installation**: Complete environment setup via single command
- **Idempotent Scripts**: Safe to run multiple times
- **Dependency Management**: Automatic installation of required tools

## Maintenance

### Adding New Files
```bash
chezmoi add ~/.config/some-app/config
```

### Updating Configuration
```bash
chezmoi edit ~/.zshrc
chezmoi apply
```

### Checking Changes
```bash
chezmoi diff
```

This dotfiles setup provides a comprehensive, modern development environment with extensive customization while maintaining simplicity through Chezmoi's management system.