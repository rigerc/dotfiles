# Comprehensive Chezmoi Documentation

## Overview

Chezmoi is a powerful dotfile manager that helps users securely manage personal configuration files across multiple diverse machines with features like templating, password manager integration, and encryption. It uses Go's text/template syntax for dynamic configuration and supports various file types and encryption methods.


## Architecture and Concepts

### Directory Structure

- **Source Directory**: `~/.local/share/chezmoi/` (default location)
- **Config Directory**: `~/.config/chezmoi/`
- **Cache Directory**: `~/.cache/chezmoi/`
- **Destination Directory**: `~` (home directory, configurable)

### File Types and Naming Conventions

| Source File Type | Target Location | Description |
|------------------|----------------|-------------|
| `dot_filename` | `~/.filename` | Regular dotfile |
| `dot_config` | `~/.config/` | Directory |
| `dot_filename.tmpl` | `~/.filename` | Template file |
| `create_dotfile` | `~/.dotfile` | Create-only (if doesn't exist) |
| `exact_dotfile` | `~/.dotfile` | Exact (remove if extra files) |
| `private_dotfile` | `~/.dotfile` | Encrypted file |
| `executable_script` | `~/.script` | Executable with permissions |
| `run_script.sh` | N/A | Run during apply |
| `symlink_filename` | `~/.filename` | Symbolic link |
| `modify_dotfile` | `~/.dotfile` | Modify existing file |
| `remove_dotfile` | `~/.dotfile` | Remove target file |
| `.chezmoiignore` | N/A | Ignore patterns file |
| `.chezmoiremove` | N/A | Files to remove |

### Special Files

- `.chezmoi.yaml`, `.chezmoi.toml`, `.chezmoi.json`: Configuration file
- `.chezmoiignore`: Ignore patterns (like .gitignore)
- `.chezmoiremove`: Files to remove during apply
- `.chezmoitemplates/`: Directory for shared templates
- `.chezmoiscripts/`: Directory for scripts

## Core Workflow

### 1. Initialize Chezmoi

```bash
# Initialize locally with new git repo
chezmoi init

# Initialize from remote repository
chezmoi init https://github.com/$GITHUB_USERNAME/dotfiles.git

# Initialize from SSH repository
chezmoi init git@github.com:$GITHUB_USERNAME/dotfiles.git

# Initialize and apply in one command
chezmoi init --apply https://github.com/$GITHUB_USERNAME/dotfiles.git

# Initialize with custom config path
chezmoi init --config-path ~/.config/chezmoi/custom.toml

# Initialize with one-shot mode (temporary environments)
chezmoi init --one-shot $GITHUB_USERNAME
```

#### Repository URL Patterns

| Pattern | HTTPS URL | SSH URL |
|---------|-----------|---------|
| `user` | `https://user@github.com/user/dotfiles.git` | `git@github.com:user/dotfiles.git` |
| `user/repo` | `https://user@github.com/user/repo.git` | `git@github.com:user/repo.git` |
| `site/user/repo` | `https://user@site/user/repo.git` | `git@site:user/repo.git` |

### 2. Manage Dotfiles

```bash
# Add existing dotfile to management
chezmoi add ~/.bashrc

# Add multiple files
chezmoi add ~/.vimrc ~/.gitconfig ~/.tmux.conf

# Add file as template
chezmoi add --template ~/.gitconfig

# Add directory recursively
chezmoi add --recursive ~/.config/nvim

# Add with specific attributes
chezmoi add --private ~/.ssh/id_rsa
chezmoi add --exact ~/.config/
chezmoi add --create ~/.local/bin/script

# Import from archive
chezmoi import --strip-components 1 --destination ~/.config/archive.tar.gz

# Remove from management
chezmoi remove ~/.bashrc
```

### 3. Edit Dotfiles

```bash
# Edit specific file source
chezmoi edit ~/.bashrc

# Edit configuration file
chezmoi edit-config

# Edit configuration template
chezmoi edit-config-template

# Navigate to source directory
chezmoi cd

# Launch shell in specific directory
chezmoi cd ~/.config
chezmoi cd ~
```

### 4. Apply and Review Changes

```bash
# Apply all changes
chezmoi apply

# Apply with verbose output
chezmoi -v apply

# Apply specific file
chezmoi apply ~/.bashrc

# Apply specific directory
chezmoi apply ~/.config/

# Show differences
chezmoi diff

# Show diff for specific file
chezmoi diff ~/.bashrc

# Show what would be applied (dry run)
chezmoi apply --dry-run

# Force apply (overwrite changes)
chezmoi apply --force
```

### 5. Version Control

```bash
# Navigate to source directory
chezmoi cd

# Commit changes
git add .
git commit -m "Update configuration"

# Add remote
git remote add origin git@github.com:$GITHUB_USERNAME/dotfiles.git
git push -u origin main

# Pull changes
git pull

# Update from remote and apply
chezmoi update
```

## Advanced Configuration

### Configuration File Formats

Chezmoi supports multiple configuration file formats:

#### TOML Configuration (`chezmoi.toml`)
```toml
[data]
    email = "user@example.com"
    name = "John Doe"

[sourceDir]
    path = "/home/user/.dotfiles"

[destDir]
    path = "/home/user"

[git]
    autoPush = true
    autoCommit = true
    command = "git"

[merge]
    command = "nvim"
    args = ["-d", "{{ .Destination }}", "{{ .Source }}", "{{ .Target }}"]

[template]
    options = ["missingkey=zero"]

[pinentry]
    command = "pinentry"
    args = []
    options = ["allow-external-password-cache"]

[onePassword]
    command = "op"
    args = ["--cache-ttl", "3600"]

[bitwarden]
    command = "bw"
    args = []

[pass]
    command = "pass"

[awsSecretsManager]
    profile = "default"
    region = "us-east-1"
```

#### YAML Configuration (`chezmoi.yaml`)
```yaml
data:
  email: user@example.com
  name: John Doe

sourceDir:
  path: /home/user/.dotfiles

git:
  autoPush: true
  autoCommit: true

merge:
  command: nvim
  args: ["-d", "{{ .Destination }}", "{{ .Source }}", "{{ .Target }}"]

template:
  options: ["missingkey=zero"]
```

#### JSON Configuration (`chezmoi.json`)
```json
{
  "data": {
    "email": "user@example.com",
    "name": "John Doe"
  },
  "sourceDir": {
    "path": "/home/user/.dotfiles"
  },
  "git": {
    "autoPush": true,
    "autoCommit": true
  }
}
```

### Environment Variables

```bash
# Configuration file location
export CHEZMOI_CONFIG_DIR="~/.config/chezmoi"

# Source directory
export CHEZMOI_SOURCE_DIR="~/.local/share/chezmoi"

# Destination directory
export CHEZMOI_DEST_DIR="~"

# Verbosity level
export CHEZMOI_VERBOSE=true

# Debug mode
export CHEZMOI_DEBUG=true
```

## Templating System

### Template Data Variables

Chezmoi provides extensive template data:

```bash
# View all available template data
chezmoi data

# View in YAML format
chezmoi data --format=yaml

# View specific data
chezmoi execute-template '{{ .chezmoi }}'
```

#### Built-in Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `.chezmoi.os` | Operating system | "linux", "darwin", "windows" |
| `.chezmoi.arch` | Architecture | "amd64", "arm64", "386" |
| `.chezmoi.hostname` | Hostname | "work-laptop" |
| `.chezmoi.username` | Username | "john" |
| `.chezmoi.homeDir` | Home directory | "/home/john" |
| `.chezmoi.sourceDir` | Source directory | "/home/john/.local/share/chezmoi" |
| `.chezmoi.cacheDir` | Cache directory | "/home/john/.cache/chezmoi" |
| `.chezmoi.configDir` | Config directory | "/home/john/.config/chezmoi" |
| `.chezmoi.version` | Chezmoi version | "2.50.0" |
| `.chezmoi.kernel.version` | Kernel version | "5.15.0" |

#### System Information

```go-template
{{- if gt .cpu.threads .cpu.cores -}}
Hyperthreaded CPU detected
{{- end -}}

Memory: {{ .memory.total }}GB
Disks: {{ range .disks }}{{ .name }} ({{ .total }}GB) {{ end }}
Network: {{ range .network.interfaces }}{{ .name }} {{ end }}
```

### Template Functions

#### String Functions
```go-template
{{ "hello" | upper }}              # "HELLO"
{{ "HELLO" | lower }}              # "hello"
{{ "hello world" | title }}        # "Hello World"
{{ "hello" | repeat 3 }}           # "hellohellohello"
{{ "hello" | replace "l" "L" }}    # "heLLo"
{{ "hello" | trim }}               # "hello"
{{ "hello" | trimPrefix "he" }}    # "llo"
{{ "hello" | trimSuffix "lo" }}    # "hel"
{{ "hello" | split "" }}           # ["h", "e", "l", "l", "o"]
{{ "hello,world" | split "," }}   # ["hello", "world"]
{{ ["h", "e", "l", "l", "o"] | join "" }}  # "hello"
{{ "hello" | quote }}              # "\"hello\""
{{ ["item1", "item2"] | quoteList }}   # ["\"item1\"", "\"item2\""]
```

#### Numeric Functions
```go-template
{{ 3.14159 | printf "%.2f" }}     # "3.14"
{{ add 1 2 }}                      # 3
{{ sub 5 2 }}                      # 3
{{ mul 3 4 }}                      # 12
{{ div 8 2 }}                      # 4
{{ mod 7 3 }}                      # 1
{{ max 1 5 3 }}                    # 5
{{ min 1 5 3 }}                    # 1
```

#### File and Path Functions
```go-template
{{ "~/.config" | expandEnv }}      # "/home/user/.config"
{{ "~/.config" | joinPath "nvim" }} # "~/.config/nvim"
{{ "/path/to/file" | base }}       # "file"
{{ "/path/to/file" | dir }}        # "/path/to"
{{ "file.txt" | ext }}             # ".txt"
{{ "file.txt" | hasPrefix "file" }} # true
{{ "file.txt" | hasSuffix ".txt" }} # true
```

#### Conditional and Logic Functions
```go-template
{{ if eq .chezmoi.os "linux" }}Linux config{{ end }}
{{ if ne .chezmoi.hostname "work" }}Home setup{{ end }}
{{ if and (eq .chezmoi.os "darwin") (eq .chezmoi.arch "arm64") }}Apple Silicon{{ end }}
{{ if or (eq .chezmoi.os "linux") (eq .chezmoi.os "darwin") }}Unix-like{{ end }}
{{ if hasKey .data "email" }}Email: {{ .data.email }}{{ end }}
```

#### Data Conversion Functions
```go-template
{{ dict "key" "value" | toJson }}   # {"key":"value"}
{{ dict "key" "value" | toYaml }}   # key: value
{{ dict "key" "value" | toToml }}   # key = "value"
{{ "hello" | toUpper }}             # "HELLO"
{{ "HELLO" | toLower }}             # "hello"
```

#### External Command Functions
```go-template
{{ output "hostname" | trim }}                     # Execute hostname command
{{ outputList "git" (list "config" "user.name") }} # Execute with args
{{ lookPath "git" }}                              # Check if git exists
{{ stat "~/.bashrc" }}                            # File info
{{ glob "~/.config/*" }}                          # Glob patterns
```

### Template Directives

```go-template
{{/* chezmoi:template:missing-key=zero */}}
{{/* chezmoi:template:format-indent="\t" */}}
{{/* chezmoi:template:format-indent-width=4 */}}
{{/* chezmoi:template:line-endings=lf */}}
```

### Template Examples

#### Conditional Configuration
```go-template
# ~/.bashrc template
{{- if eq .chezmoi.os "darwin" }}
export PATH="/opt/homebrew/bin:$PATH"
{{- else if eq .chezmoi.os "linux" }}
export PATH="/usr/local/bin:$PATH"
{{- end }}

{{- if eq .chezmoi.hostname "work-laptop" }}
export WORK_MODE=true
{{- end }}

export EDITOR="{{ if lookPath "nvim" }}nvim{{ else }}vim{{ end }}"
```

#### Including Templates
```go-template
# Main template
{{ template "header" . }}
{{ template "ssh-config" . }}
{{ template "git-config" . }}

# .chezmoitemplates/header.tmpl
# Generated by chezmoi
# Do not edit manually
# Host: {{ .chezmoi.hostname }}
# OS: {{ .chezmoi.os }}/{{ .chezmoi.arch }}

# .chezmoitemplates/ssh-config.tmpl
{{ if .ssh.enabled }}
Host github.com
    User git
    IdentityFile ~/.ssh/{{ .ssh.key_file }}
{{ end }}
```

#### Dynamic Content
```go-template
# Kubernetes config
current-context: {{ output "kubectl" "config" "current-context" | trim }}

# Git config with user data
[user]
    name = {{ .data.name | quote }}
    email = {{ .data.email | quote }}

# Package installation script
{{- if eq .chezmoi.os "linux" }}
#!/bin/bash
sudo apt update
sudo apt install -y {{ join .packages.linux " " }}
{{- else if eq .chezmoi.os "darwin" }}
#!/bin/bash
brew install {{ join .packages.darwin " " }}
{{- end }}
```

## Password Manager Integration

### Bitwarden Integration

```toml
# chezmoi.toml
[bitwarden]
    command = "bw"
    args = []
```

```go-template
# Template usage
{{- bitwarden "item" "api-key" -}}
{{- bitwarden "attachment" "id_rsa" "item" "ssh-keys" -}}
{{- bitwardenFields "item" "username" -}}
{{- bitwardenGet "notes" -}}
```

### 1Password Integration

```toml
# chezmoi.toml
[onePassword]
    command = "op"
    args = ["--cache-ttl", "3600"]
```

```go-template
# Template usage
{{- onepassword "document" "uuid" -}}
{{- onepasswordDocument "uuid" -}}
{{- onepasswordItem "item" "field" -}}
{{- onepasswordRead "path" -}}
```

### Pass Integration

```toml
# chezmoi.toml
["pass"]
    command = "pass"
```

```go-template
# Template usage
{{- pass "email@example.com" -}}
{{- passFields "email@example.com" -}}
```

### AWS Secrets Manager Integration

```toml
# chezmoi.toml
[awsSecretsManager]
    profile = "default"
    region = "us-east-1"
```

```go-template
# Template usage
{{ (awsSecretsManager "my-secret").username }}
{{ awsSecretsManagerRaw "my-string-secret" }}
```

### Generic Secret Functions

```go-template
# Configure secret command
# chezmoi.toml
[secret]
    command = "my-secret-tool"
    args = []

# Template usage
{{ secret "secret-name" }}
{{ secretBytes "secret-binary" }}
{{ secretFile "secret-file" }}
{{ secretFileBytes "secret-file-binary" }}
```

## Command Reference

### Core Commands

#### `chezmoi init`
```bash
chezmoi init [repo] [flags]
```

**Flags:**
- `-a, --apply`: Run `chezmoi apply` after initialization
- `--branch string`: Check out specific branch
- `-C, --config-path string`: Config file path
- `--data`: Include existing template data
- `-d, --depth int`: Clone with specified depth
- `--git-lfs`: Run `git lfs pull` after clone
- `-g, --guess-repo-url`: Guess repo URL (default true)
- `--one-shot`: Apply and remove all traces
- `--prompt`: Force prompts
- `-p, --purge`: Remove source and config directories
- `--promptBool string=value`: Simulate promptBool
- `--promptChoice string=value`: Simulate promptChoice
- `--promptInt string=value`: Simulate promptInt
- `--promptString string=value`: Simulate promptString
- `--promptMultichoice string=value`: Simulate promptMultichoice

#### `chezmoi add`
```bash
chezmoi add [flags] target...
```

**Flags:**
- `--template`: Add as template
- `--recursive`: Add directories recursively
- `--private`: Encrypt file
- `--exact`: Exact directory
- `--create`: Create-only file
- `--autotemplate`: Automatically create template
- `-f, --force`: Force add even if ignored
- `--exclude pattern`: Exclude pattern

#### `chezmoi apply`
```bash
chezmoi apply [flags] [target...]
```

**Flags:**
- `--dry-run`: Show what would be applied
- `-f, --force`: Force apply
- `--remove`: Remove files not in source
- `--source-path string`: Source directory
- `-t, --target string`: Target directory

#### `chezmoi edit`
```bash
chezmoi edit [flags] [target]
```

**Flags:**
- `--apply`: Apply after editing
- `--diff`: Show diff after editing
- `-p, --prompt`: Prompt before editing

### Management Commands

#### `chezmoi cd`
```bash
chezmoi cd [directory]
```

#### `chezmoi diff`
```bash
chezmoi diff [flags] [target...]
```

**Flags:**
- `--exclude pattern`: Exclude pattern
- `--max-lines int`: Maximum diff lines
- `--output string`: Output file

#### `chezmoi managed`
```bash
chezmoi managed [flags] [target...]
```

#### `chezmoi unmanaged`
```bash
chezmoi unmanaged [flags] [target...]
```

#### `chezmoi remove`
```bash
chezmoi remove [flags] target...
```

**Flags:**
- `-f, --force`: Force remove

### Template Commands

#### `chezmoi execute-template`
```bash
chezmoi execute-template [flags] [template...]
```

**Flags:**
- `-f, --file`: Treat arguments as filenames
- `-i, --init`: Include init functions
- `--left-delimiter string`: Custom left delimiter
- `--right-delimiter string`: Custom right delimiter
- `--promptString string=value`: Simulate prompts
- `--with-stdin`: Include stdin in .chezmoi.stdin

#### `chezmoi data`
```bash
chezmoi data [flags]
```

**Flags:**
- `-f, --format string`: Output format (json, yaml, toml)

#### `chezmoi cat`
```bash
chezmoi cat [flags] [target...]
```

#### `chezmoi merge`
```bash
chezmoi merge [flags] target
```

**Flags:**
- `-k, --keep-tempfiles`: Keep temporary files

### State Management

#### `chezmoi state`
```bash
chezmoi state [command]
```

**Commands:**
- `data`: Show all state data
- `get`: Get specific value
- `set`: Set value
- `delete`: Delete entry
- `delete-bucket`: Delete bucket
- `dump`: Dump state
- `get-bucket`: Get bucket
- `reset`: Reset state

### Utility Commands

#### `chezmoi completion`
```bash
chezmoi completion [shell]
```

**Shells:** bash, fish, zsh, powershell

#### `chezmoi doctor`
```bash
chezmoi doctor [flags]
```

#### `chezmoi import`
```bash
chezmoi import [flags] archive
```

**Flags:**
- `--strip-components int`: Strip path components
- `--destination string`: Destination directory

#### `chezmoi verify`
```bash
chezmoi verify [flags]
```

## Hooks and Scripts

### Run Scripts

Create scripts that execute during `chezmoi apply`:

```bash
# run_once_01-install-packages.sh
#!/bin/bash
# Runs only once

if command -v apt >/dev/null; then
    sudo apt update
    sudo apt install -y vim git curl
elif command -v brew >/dev/null; then
    brew install vim git curl
fi
```

```bash
# run_onchange_99-update-packages.sh
#!/bin/bash
# Runs when script changes

# Update package lists
if command -v apt >/dev/null; then
    sudo apt update
elif command -v brew >/dev/null; then
    brew update
fi
```

### Script Types

| Prefix | Behavior |
|--------|----------|
| `run_once_` | Execute only once |
| `run_onchange_` | Execute when script changes |
| `run_before_` | Execute before apply |
| `run_after_` | Execute after apply |

### Hooks Configuration

```toml
[hooks.read-source-state.pre]
    command = ".local/share/chezmoi/.install-password-manager.sh"

[hooks.apply.pre]
    command = "echo", "Starting apply..."

[hooks.apply.post]
    command = "echo", "Apply completed"
```

## Advanced Workflows

### Multi-Machine Setup

```go-template
# .chezmoi.yaml.tmpl
{{- $email := promptStringOnce . "email" "Email address" -}}
{{- $fullname := promptStringOnce . "fullname" "Full name" -}}

data:
    email: {{ $email | quote }}
    fullname: {{ $fullname | quote }}
    work: {{ promptBoolOnce . "work" "Is this a work machine?" }}

{{- if .work }}
{{- $company := promptStringOnce . "company" "Company name" -}}
data:
    company: {{ $company | quote }}
{{- end }}
```

### Conditional Package Installation

```bash
# run_onchange_99-install-packages.sh.tmpl
#!/bin/bash

{{- if eq .chezmoi.os "linux" }}
{{- if .work }}
# Work packages
sudo apt install -y keepassxc slack-desktop
{{- else }}
# Personal packages
sudo apt install -y vlc gimp
{{- end }}
{{- else if eq .chezmoi.os "darwin" }}
{{- if .work }}
brew install --cask keepassxc slack
{{- else }}
brew install --cask vlc gimp
{{- end }}
{{- end }}
```

### Environment-Specific Configuration

```go-template
# .config/nvim/init.lua.tmpl
{{- if .work }}
-- Work Neovim configuration
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
{{- else }}
-- Personal Neovim configuration
vim.opt.expandtab = false
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
{{- end }}

-- Common configuration
vim.opt.number = true
vim.opt.relativenumber = true
```

### Backup and Restore

```bash
# Create backup archive
chezmoi archive --output backup.tar.gz

# Restore from archive
chezmoi extract --force backup.tar.gz

# Generate installation script
chezmoi generate install.sh > install.sh
chmod +x install.sh
```

### Integration with Other Tools

#### Git Hooks
```bash
# Pre-commit hook to run chezmoi verify
#!/bin/bash
chezmoi verify --source-path .
```

#### CI/CD Integration
```yaml
# .github/workflows/dotfiles.yml
name: Test Dotfiles
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: actions/setup-go@v2
      with:
        go-version: '1.19'
    - run: |
        curl -sfL https://chezmoi.io/install.sh | sh
        chezmoi init --source-path=. --destination=/tmp/test-home
        chezmoi verify
```

#### Docker Integration
```dockerfile
# Dockerfile
FROM ubuntu:latest
RUN apt-get update && apt-get install -y curl
RUN curl -sfL https://chezmoi.io/install.sh | sh
COPY . /tmp/dotfiles
RUN chezmoi init --source-path=/tmp/dotfiles --apply
```

## Troubleshooting and FAQ

### Common Issues

#### Permission Denied
```bash
# Check file permissions
ls -la ~/.config/chezmoi/
ls -la ~/.local/share/chezmoi/

# Fix permissions
chmod 755 ~/.config/chezmoi/
chmod 644 ~/.config/chezmoi/chezmoi.toml
```

#### Template Errors
```bash
# Test template syntax
chezmoi execute-template < template.tmpl

# Check template data
chezmoi data

# Debug specific template
chezmoi cat ~/.config/example
```

#### Merge Conflicts
```bash
# Resolve conflicts
chezmoi merge ~/.config/conflict-file

# Use specific merge tool
chezmoi merge --tool=vimdiff ~/.config/conflict-file

# Force apply after resolving
chezmoi apply --force
```

#### Encryption Issues
```bash
# Check GPG configuration
gpg --list-secret-keys

# Test encryption
echo "test" | gpg --encrypt --armor --recipient user@example.com

# Re-encrypt encrypted files
chezmoi re-add --private ~/.ssh/id_rsa
```

### Debug Mode

```bash
# Enable verbose output
chezmoi -v apply

# Enable debug mode
chezmoi --debug apply

# Debug template execution
chezmoi --debug execute-template '{{ .chezmoi }}'

# Check configuration
chezmoi cat-config
```

### Performance Issues

```bash
# Use cache for expensive operations
chezmoi state set --bucket=cache --key=kubectl-context --value="$(kubectl config current-context)"

# Limit scope of operations
chezmoi apply ~/.config/nvim/
chezmoi diff ~/.bashrc

# Use parallel processing
chezmoi apply --parallel
```

### Recovery Procedures

#### Restore from Backup
```bash
# Restore from git history
chezmoi cd
git log --oneline
git checkout <commit> -- .
chezmoi apply

# Restore from archive
chezmoi extract backup.tar.gz --force
```

#### Reset Configuration
```bash
# Remove all state
chezmoi state reset

# Re-initialize
chezmoi init --force

# Generate new config
chezmoi edit-config-template
```

### Best Practices

1. **Security**
   - Encrypt sensitive files with `chezmoi add --private`
   - Use password managers for secrets
   - Review `.chezmoiignore` for sensitive files
   - Don't commit sensitive data

2. **Organization**
   - Use logical directory structure
   - Group related configurations
   - Use descriptive file names
   - Document custom scripts

3. **Version Control**
   - Commit frequently
   - Use meaningful commit messages
   - Tag important configurations
   - Use branches for experimental changes

4. **Templates**
   - Keep templates simple
   - Test template changes
   - Use shared templates for common patterns
   - Document template variables

5. **Performance**
   - Limit template complexity
   - Cache expensive operations
   - Use specific targets when possible
   - Regular cleanup of unused files

## Additional Resources

### Official Documentation
- [Chezmoi Website](https://chezmoi.io/)
- [Chezmoi GitHub Repository](https://github.com/twpayne/chezmoi)
- [User Guide](https://chezmoi.io/docs/user-guide/)
- [Reference Manual](https://chezmoi.io/docs/reference/)

### Community Resources
- [Chezmoi Wiki](https://github.com/twpayne/chezmoi/wiki)
- [Example Configurations](https://github.com/twpayne/chezmoi/tree/master/examples)
- [Community Showcase](https://github.com/twpayne/chezmoi/discussions/categories/show-and-tell)

### Related Tools
- [GNU Stow](https://www.gnu.org/software/stow/)
- [Dotbot](https://github.com/anishathalye/dotbot)
- [YADM](https://yadm.io/)
- [Homeshick](https://github.com/andsens/homeshick)

### Tutorials and Articles
- [Managing Dotfiles with Chezmoi](https://jasonmunix.medium.com/managing-dotfiles-with-chezmoi-f3e4c7e8a5f3)
- [Chezmoi Template Guide](https://carlosbecker.com/posts/chezmoi-templates/)
- [Chezmoi and Password Managers](https://www.chezmoi.io/docs/user-guide/password-managers/)