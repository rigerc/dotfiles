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

## Session Start

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

### Development Tools Integration
- **Eza**: Modern `ls` replacement with git integration and icons
- **Zoxide**: Smart directory navigation with `z` command and fzf integration (`zif`, `zif_preview`)
- **FZF**: Fuzzy finder with custom default options
- **Tmux**: Auto-start with session management functions (`tmux-session`, `tmux-switch`)

## Architecture Notes

### Plugin Management
- **Zsh**: Zinit loads plugins with optimized completion handling
- **Neovim**: LazyVim ecosystem with lazy.nvim for plugin management
- **Tmux**: TPM (Tmux Plugin Manager) for plugin management

### Environment Configuration
 chezmoi script environment variables are defined in `dot_config/chezmoi/chezmoi.toml`, including:
- Editor preferences (nvim)
- FZF default commands and options
- XDG base directory specifications
- Tool configurations (ripgrep, bat, etc.)

### Cross-Platform Compatibility
The setup supports both macOS and Linux with:
- Platform-specific Homebrew installation paths
- Build tools installation for Linux distributions
- Consistent tool configurations across platforms

This is a personal development environment setup focused on:
- Cross-platform compatibility (macOS/Linux)
- Modern terminal experience with plugins and themes
- Efficient development workflows with integrated tools
- Git integration and aliases