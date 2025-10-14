#!/bin/bash
# bootstrap.sh - Initial setup script for chezmoi dotfiles
# Usage: sh -c "$(curl -fsLS https://your-repo/bootstrap.sh)"

set -e

echo "🚀 Starting dotfiles installation..."

# Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH based on architecture
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Install chezmoi if not installed
if ! command -v chezmoi &> /dev/null; then
    echo "📦 Installing chezmoi..."
    brew install chezmoi
fi

# Initialize chezmoi with your dotfiles repo
echo "🔧 Initializing chezmoi..."
# Replace YOUR_GITHUB_USERNAME with your actual username
chezmoi init --apply rigerc/dotfiles

echo "✅ Installation complete! Please restart your shell or run: source ~/.zshrc"