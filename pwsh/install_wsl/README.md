# WSL Installation Script - Modularized Version

This directory contains a modularized version of the WSL ArchLinux installation script. The original monolithic script has been broken down into logical modules for better maintainability and reusability.

## Structure

```
pwsh/install_wsl/
├── Install-WSLArchLinux.ps1    # Main entry point script
├── Modules/
│   ├── WSL-Install.psd1         # Module manifest
│   ├── WSL-Logging.psm1         # Logging functions
│   ├── WSL-Helpers.psm1         # Helper utilities
│   ├── WSL-SystemSetup.psm1     # WSL system component installation
│   ├── WSL-Validation.psm1      # Validation and testing functions
│   ├── WSL-Command.psm1         # WSL command execution
│   ├── WSL-Management.psm1      # WSL distribution management
│   ├── WSL-PackageManager.psm1  # Package management functions
│   ├── WSL-UserManagement.psm1  # User creation and sudo configuration
│   ├── WSL-Input.psm1           # User input and configuration
│   ├── WSL-Chezmoi.psm1         # Chezmoi dotfiles management
│   ├── WSL-SSH.psm1             # SSH configuration and port forwarding
│   └── WSL-Workflow.psm1        # Main workflow orchestration
└── README.md                    # This file
```

## Module Descriptions

### Core Modules

- **WSL-Logging.psm1**: Provides formatted logging with timestamps, color-coded severity levels, section headers, and progress logging.
- **WSL-Helpers.psm1**: Contains utility functions for output redirection, WSL exit code testing, and output formatting.
- **WSL-Validation.psm1**: Provides validation functions for usernames, system availability, and WSL distribution status.

### System and Management Modules

- **WSL-SystemSetup.psm1**: Handles installation of WSL features, kernel updates, and setting WSL2 as default.
- **WSL-Command.psm1**: Provides functions for executing commands in WSL distributions both programmatically and interactively.
- **WSL-Management.psm1**: Contains functions for installing, removing, and managing WSL distributions.
- **WSL-PackageManager.psm1**: Handles pacman initialization, package installation, and package manager status checking.

### Configuration and User Modules

- **WSL-UserManagement.psm1**: Provides user creation, sudo configuration, and user testing functions.
- **WSL-Input.psm1**: Handles user input gathering, validation, and configuration display.
- **WSL-Chezmoi.psm1**: Manages Chezmoi dotfiles setup and git configuration.
- **WSL-SSH.psm1**: Configures SSH port forwarding, firewall rules, and SSH service management.

### Workflow Module

- **WSL-Workflow.psm1**: Orchestrates the main installation workflows including continue mode, normal mode, Chezmoi setup, and completion summaries.

## Usage

### Basic Usage

Run the main script with administrator privileges:

```powershell
# Run with interactive prompts
.\Install-WSLArchLinux.ps1

# Run with default values
.\Install-WSLArchLinux.ps1 -WithDefaults

# Run with Chezmoi setup
.\Install-WSLArchLinux.ps1 -WithChezmoi

# Run with defaults and Chezmoi
.\Install-WSLArchLinux.ps1 -WithDefaults -WithChezmoi

# Continue mode (work with existing distribution)
.\Install-WSLArchLinux.ps1 -Continue -WithDefaults
```

### Debug Mode

Enable debug output for troubleshooting:

```powershell
.\Install-WSLArchLinux.ps1 -Debug
```

## Module Dependencies

The modules are designed to work together with the following dependencies:

- **WSL-Logging**: Used by all other modules for consistent logging
- **WSL-Helpers**: Provides utilities used by multiple modules
- **WSL-Validation**: Used by workflow and management modules
- **WSL-Command**: Used by modules that need to execute WSL commands

## Features

### Original Features Preserved

- WSL feature installation (Windows Subsystem for Linux, Virtual Machine Platform)
- WSL2 kernel update and default version setting
- ArchLinux distribution installation
- Package manager initialization (pacman keyring, system updates)
- User creation with passwordless sudo configuration
- Optional Chezmoi dotfiles management setup
- Optional SSH port forwarding and firewall configuration
- Continue mode for working with existing distributions
- Comprehensive error handling and logging
- Progress tracking with visual feedback

### New Modular Benefits

- **Maintainability**: Each module focuses on a specific responsibility
- **Reusability**: Individual modules can be used in other scripts
- **Testing**: Modules can be tested independently
- **Debugging**: Issues can be isolated to specific modules
- **Extensibility**: New functionality can be added as separate modules

## Configuration

The script uses the following default values:

- **Default Distribution**: `archlinux`
- **Default Name**: `newarchlinux`
- **Default Username**: First part of Windows username (lowercase)
- **Required Packages**: `archinstall`, `sudo`, `chezmoi`
- **Max Ready Attempts**: 30
- **Ready Delay**: 5 seconds

## Error Handling

All modules include comprehensive error handling:

- WSL command execution failures are caught and logged
- Distribution readiness is verified before operations
- Package installation failures are handled gracefully
- User configuration is tested and verified
- Rollback is attempted where possible

## Logging

The script provides detailed logging with:

- Timestamped messages
- Color-coded severity levels (Info, Warning, Error, Success, Debug)
- Section headers for major operations
- Progress indicators for long-running operations
- Debug mode with detailed execution information

## Requirements

- Windows 10/11 with WSL support
- PowerShell 5.1 or later
- Administrator privileges for WSL feature installation
- Internet connection for distribution downloads

## License

This modularized version maintains the same license as the original script.