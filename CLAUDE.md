# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **chezmoi-based** personal dotfiles repository. The repository contains configuration files for various development tools and shell environments, primarily focused on Zsh and Neovim setups.

**This dotfiles repository uses chezmoi** for dotfile management. chezmoi is a tool for managing dotfiles across multiple machines, keeping configuration files synchronized and properly deployed.

## Key Structure

### chezmoi Integration
- Files are stored with `dot_` prefix (e.g., `dot_zshrc`, `dot_p10k.zsh`)
- chezmoi manages these to create actual dotfiles in the home directory
- Configuration files in `dot_config/` map to `~/.config/`
- Template files (`.tmpl`) use chezmoi template syntax for dynamic configuration
- Data files in `.chezmoidata/` for template variables (e.g., `packages.yaml`)

### Installation Scripts
- `run_once_01-install-homebrew.sh.tmpl` - Installs Homebrew and sets up environment
- `run_onchange_99-install-homebrew-packages.sh.tmpl` - Installs packages from chezmoi data
- `run_once_install-zsh.sh` - Sets up Zsh as default shell with Zinit
- `run_once_install-nerd-font.sh` - Installs Iosevka Nerd Font
- `run_once_install-uv.sh` - Installs uv Python package manager
- `run_once_after_install-tpm.sh` - Post-install setup for tmux plugin manager

### Core Configurations
- **Zsh setup**: Uses **Zinit** plugin manager with Powerlevel10k theme. **This Zsh configuration uses Zinit** for plugin management and loading.
- **Neovim**: LazyVim-based configuration using lazy.nvim plugin manager
- **Tmux**: Auto-start configuration with session management functions
- **Development tools**: Package definitions in `.chezmoidata/packages.yaml`

## Quick Start

### Initial Installation
For a new system, initialize with:
```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply rigerc
```

### Directory Overview
At the start of each session, list all files in this directory using:
```bash
tree -a -I '.git'
```

## Common Operations

### Installing/Updating Dotfiles
The dotfiles use chezmoi template syntax (e.g., `{{ .chezmoi.sourceDir }}`) for dynamic paths. Apply changes with:
```bash
chezmoi apply
```

### Installation Script Details
- `run_once_01-install-homebrew.sh.tmpl` - Installs Homebrew with platform-specific paths
- `run_onchange_99-install-homebrew-packages.sh.tmpl` - Installs packages from `.chezmoidata/packages.yaml`
- `run_once_install-zsh.sh` - Sets up Zsh as default shell and installs Zinit
- `run_once_install-nerd-font.sh` - Installs Iosevka Nerd Font for terminal icons
- `run_once_install-uv.sh` - Installs uv Python package manager
- `run_once_after_install-tpm.sh` - Post-install setup for tmux plugin manager
- `run_once_install-ssh-server.sh.tmpl` - Installs and configures OpenSSH server on port 4444

### Initial System Setup
For a new system, run the installation scripts in order:
```bash
# chezmoi will automatically execute run_once_* scripts
chezmoi apply
```

### Package Management
Packages are defined in `.chezmoidata/packages.yaml` and installed via chezmoi templates:
```bash
# Trigger package installation by updating the data file or running:
chezmoi apply
```

### Shell Configuration
- **Zsh uses Zinit plugin manager** for loading and managing plugins
- Powerlevel10k configuration is in `dot_p10k.zsh`
- Aliases and shell settings in `dot_zshrc`
- Tmux integration in `dot_config/zsh/tmux.zsh`
- SSH server management functions in `dot_config/zsh/ssh-functions.zsh`

### Development Tools Integration
- **Eza**: Modern `ls` replacement with git integration and icons
- **Zoxide**: Smart directory navigation with `z` command and fzf integration (`zif`, `zif_preview`)
- **FZF**: Fuzzy finder with custom default options
- **Tmux**: Auto-start with session management functions (`tmux-session`, `tmux-switch`)
- **SSH Server**: OpenSSH server running on port 4444 with management functions

## Architecture Notes

### Plugin Management
- **Zsh**: Zinit loads plugins with optimized completion handling
- **Neovim**: LazyVim ecosystem with lazy.nvim for plugin management
- **Tmux**: TPM (Tmux Plugin Manager) for plugin management

### Environment Configuration
 chezmoi script environment variables are defined in `dot_config/chezmoi/chezmoi.toml`, including:
- Editor preferences (nvim)
- FZF default commands and options with ripgrep integration
- XDG base directory specifications
- Tool configurations (ripgrep, bat, git delta, etc.)
- Shell history settings and language configuration

### Package Structure
The `.chezmoidata/packages.yaml` defines:
- **Development tools**: Node, Python, Go, Rust, GitHub CLI, lazygit
- **Text editors**: Neovim, nano
- **Modern utilities**: eza (ls replacement), zoxide (smart cd), fzf, bat, ripgrep, fd
- **Shell tools**: Zsh, tmux, jq, yq, htop, fastfetch

### Cross-Platform Compatibility
The setup supports both macOS and Linux with:
- Platform-specific Homebrew installation paths
- Build tools installation for Linux distributions
- Consistent tool configurations across platforms

## SSH Server Management

### SSH Server Setup
The dotfiles include OpenSSH server configuration running on **port 4444** with:
- Key-based authentication (password authentication disabled)
- User restrictions and security hardening
- Platform-specific service management (macOS/Linux)

### SSH Management Commands
```bash
# Start SSH server
ssh-start

# Stop SSH server
ssh-stop

# Restart SSH server
ssh-restart

# Check SSH server status
ssh-status

# Edit SSH configuration
ssh-config

# View SSH logs
ssh-log

# Generate new SSH key pair
ssh_generate_key [type] [name] [email]

# Show connection information
ssh_connection_info [hostname] [port] [username]
```

### SSH Configuration Files
- `dot_config/ssh/sshd_config.tmpl` - SSH daemon configuration
- `dot_config/ssh/ssh_config.tmpl` - SSH client configuration
- `dot_config/ssh/authorized_keys.tmpl` - SSH public keys template
- `dot_config/ssh/launchd/org.openbsd.sshd.plist.tmpl` - macOS service config
- `dot_config/ssh/systemd/ssh-user.service.tmpl` - Linux user service config

### SSH Security Notes
- Server runs on port 4444 (non-standard port for security)
- Only public key authentication is enabled
- User access is restricted to the current user
- Root login is disabled
- Connection timeouts and session limits are configured

This is a personal development environment setup focused on:
- Cross-platform compatibility (macOS/Linux)
- Modern terminal experience with plugins and themes
- Efficient development workflows with integrated tools
- Git integration and aliases
- Secure SSH server access for remote development