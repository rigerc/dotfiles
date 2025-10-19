#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Sets up WSL system components and ArchLinux distribution with user creation and sudo configuration.

.DESCRIPTION
    Automates the installation and configuration of WSL and ArchLinux, including:
    - Installing Windows Subsystem for Linux feature
    - Installing Virtual Machine Platform feature
    - Installing WSL2 kernel update
    - Setting WSL2 as default version
    - Prompting for distribution name, image name, and username
    - Removing existing distribution if present
    - Installing the distribution
    - Running initial package manager setup
    - Creating a new user with sudo privileges
    - Configuring passwordless sudo
    - Optional Chezmoi dotfiles management setup
    - Optional SSH port forwarding configuration
    
    When using -Continue, the script will:
    - Skip WSL feature installation
    - Verify the specified distribution exists
    - Check if package manager initialization is needed (sudo availability)
    - Check if user creation is needed
    - Check if Chezmoi setup is needed

.AUTHOR
    Generated script (Refactored)

.EXAMPLE
    .\Install-WSLArchLinux.ps1
    
.EXAMPLE
    .\Install-WSLArchLinux.ps1 -WithChezmoi

.EXAMPLE
    .\Install-WSLArchLinux.ps1 -WithDefaults
    
.EXAMPLE
    .\Install-WSLArchLinux.ps1 -WithDefaults -WithChezmoi

.EXAMPLE
    .\Install-WSLArchLinux.ps1 -Continue -WithDefaults
    Skips WSL installation and works with existing distribution.
#>

#Requires -RunAsAdministrator

param(
    [switch]$WithChezmoi,
    [switch]$WithDefaults,
    [switch]$Continue,
    [switch]$Debug
)

# ============================================================================
# Configuration and Constants
# ============================================================================

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'

# Get current Windows username for default
$WindowsUser = $env:USERNAME
$FirstName = $WindowsUser.Split('.')[0]

# Default values - these are accessible to imported modules
$script:DefaultDistro = 'archlinux'
$script:DefaultName = 'newarchlinux'
$script:DefaultUsername = $FirstName.ToLower()

# Define the packages to be installed/checked - these are accessible to imported modules
$script:PackageManagerPackages = @('archinstall', 'sudo', 'chezmoi')

# Timeout and retry constants
$script:DistributionReadyMaxAttempts = 30
$script:DistributionReadyDelaySeconds = 5

# ============================================================================
# Import Modules
# ============================================================================

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Create a hashtable to pass parameters to modules
$Global:WSLScriptParams = @{
    Debug = $Debug
    DefaultDistro = $DefaultDistro
    DefaultName = $DefaultName
    DefaultUsername = $DefaultUsername
    PackageManagerPackages = $PackageManagerPackages
    DistributionReadyMaxAttempts = $DistributionReadyMaxAttempts
    DistributionReadyDelaySeconds = $DistributionReadyDelaySeconds
}

# Import all modules with parameters
Import-Module (Join-Path $ScriptDir "Modules\WSL-Logging.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-Helpers.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-SystemSetup.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-Validation.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-Command.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-Management.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-PackageManager.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-UserManagement.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-Input.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-Chezmoi.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-SSH.psm1") -Force -ArgumentList $Global:WSLScriptParams
Import-Module (Join-Path $ScriptDir "Modules\WSL-Workflow.psm1") -Force -ArgumentList $Global:WSLScriptParams

# ============================================================================
# Main Function
# ============================================================================

function Main {
    <#
    .SYNOPSIS
        Main entry point for the script.
    #>
    [CmdletBinding()]
    param()
    
    Write-Section "WSL Distribution Setup"
    Write-LogMessage "Script started with parameters: Continue=$Continue, WithChezmoi=$WithChezmoi, WithDefaults=$WithDefaults, Debug=$Debug" -Level Debug
    
    try {
        # Install WSL features (unless in Continue mode)
        if ($Continue) {
            Write-Section "Continue Mode - Skipping WSL Feature Installation"
            Write-LogMessage "Skipping WSL feature installation as requested" -Level Info
        }
        else {
            Write-Section "Installing WSL System Components"
            $RebootRequired = Install-WSLFeatures
            
            if ($RebootRequired) {
                Write-LogMessage "System restart is required to complete WSL installation." -Level Warning
                Write-LogMessage "Please restart your computer and run this script again." -Level Warning
                Write-Host ""
                Write-LogMessage "After restarting, you can continue with the distribution setup." -Level Info
                return
            }
        }
        
        # Gather configuration
        $Config = Get-ConfigurationInput -ContinueMode:$Continue -UseDefaults:$WithDefaults -WithChezmoi:$WithChezmoi
        
        # Display configuration and confirm
        Show-ConfigurationSummary -Config $Config -ContinueMode:$Continue
        
        if (-not $WithDefaults) {
            $Confirm = Read-Host "Proceed with these settings? (Y/n)"
            if ($Confirm -eq 'n' -or $Confirm -eq 'N') {
                Write-LogMessage "Setup cancelled by user" -Level Warning
                return
            }
        }
        else {
            Write-LogMessage "Proceeding automatically with default settings..." -Level Info
        }
        
        # Execute appropriate workflow
        if ($Continue) {
            Invoke-ContinueModeWorkflow -Config $Config
        }
        else {
            Invoke-NormalModeWorkflow -Config $Config
        }
        
        # Handle Chezmoi setup if requested
        Invoke-ChezmoiWorkflow -Config $Config
        
        # Configure SSH if requested
        Invoke-SSHConfiguration -DistroName $Config.DistroName -UseDefaults:$WithDefaults
        
        # Show completion summary
        Show-CompletionSummary -Config $Config
    }
    catch {
        Write-LogMessage "Setup failed: $($_.Exception.Message.Trim())" -Level Error
        Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" -Level Error
        exit 1
    }
}

# Execute main function
Main