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

### Installation Scripts
- `run_once_install-homebrew.sh` - Installs Homebrew and packages from Brewfile
- `run_once_install-zsh.sh` - Sets up Zsh as default shell with Zinit
- `run_once_install-nerd-font.sh` - Installs Iosevka Nerd Font

### Core Configurations
- **Zsh setup**: Uses **Zinit** plugin manager with Powerlevel10k theme. **This Zsh configuration uses Zinit** for plugin management and loading.
- **Neovim**: Lua-based configuration in `dot_config/nvim/`
- **Development tools**: Brewfile defines tools like Node, Python, Go, Rust, etc.

## Common Operations

### Installing/Updating Dotfiles
The dotfiles use chezmoi template syntax (e.g., `{{ .chezmoi.sourceDir }}`) for dynamic paths. Apply changes with:
```bash
chezmoi apply
```

### Package Management
Use Homebrew with the Brewfile:
```bash
brew bundle --file Brewfile
```

### Shell Configuration
- **Zsh uses Zinit plugin manager** for loading and managing plugins
- Powerlevel10k configuration is in `dot_p10k.zsh`
- Aliases and shell settings in `dot_zshrc`

## Architecture Notes

This is a personal development environment setup focused on:
- Cross-platform compatibility (macOS/Linux)
- Minimal but effective tooling
- Git integration and aliases
- Modern terminal experience with plugins and themes