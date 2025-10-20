# ============================================================================
# WSL Chezmoi Module
# ============================================================================

<#
.SYNOPSIS
    Provides Chezmoi dotfiles management functions for WSL distributions.

.DESCRIPTION
    This module contains functions for setting up Chezmoi, managing git configuration,
    and verifying Chezmoi installations.

.PARAMETER Parameters
    Hashtable containing script parameters and configuration values.
#>

# Accept parameters from the main script
param(
    [Parameter(Mandatory)]
    [hashtable]$Parameters
)

# Extract parameters from the hashtable
$script:Debug = $Parameters.Debug
$script:DefaultDistro = $Parameters.DefaultDistro
$script:DefaultName = $Parameters.DefaultName
$script:DefaultUsername = $Parameters.DefaultUsername
$script:PackageManagerPackages = $Parameters.PackageManagerPackages
$script:DistributionReadyMaxAttempts = $Parameters.DistributionReadyMaxAttempts
$script:DistributionReadyDelaySeconds = $Parameters.DistributionReadyDelaySeconds

# ============================================================================
# Chezmoi Functions
# ============================================================================

function Get-GitConfig {
    <#
    .SYNOPSIS
        Retrieves git configuration values from the local system.
    .PARAMETER ConfigKey
        The git config key to retrieve (e.g., "user.name").
    .OUTPUTS
        [string] The configuration value or null if not found.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigKey
    )
    
    if (-not (Test-GitAvailable)) {
        return $null
    }
    
    try {
        $Value = git config --global --get $ConfigKey 2>$null
        return $Value
    }
    catch {
        return $null
    }
}

function Test-ChezmoiInstallation {
    <#
    .SYNOPSIS
        Verifies that Chezmoi was installed successfully.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Username
        The username to check.
    .OUTPUTS
        [bool] True if Chezmoi is installed and verified, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username
    )
    
    Write-Section "Verifying Chezmoi Installation"
    
    try {
        Write-LogMessage "Checking if Chezmoi directory exists..." -Level Info
        
        $Command = "test -d ~/.local/share/chezmoi/ && echo 'exists' || echo 'not_found'"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -Username $Username -Quiet
        
        if ($Result -notmatch "exists") {
            Write-LogMessage "Chezmoi installation failed - ~/.local/share/chezmoi/ directory not found" -Level Error
            return $false
        }
        
        Write-LogMessage "Chezmoi directory exists, running 'chezmoi verify'..." -Level Info
        
        # Run chezmoi verify and check exit code
        $VerifyCommand = "chezmoi verify >/dev/null 2>&1 && echo 'verify_success' || echo 'verify_failed'"
        $VerifyResult = Invoke-WSLCommand -DistroName $DistroName -Command $VerifyCommand -Username $Username -Quiet
        
        if ($VerifyResult -match "verify_success") {
            Write-LogMessage "Chezmoi installation verified - all targets match their target state" -Level Success
            return $true
        }
        else {
            Write-LogMessage "Chezmoi verification failed - some targets do not match their target state" -Level Warning
            return $false
        }
    }
    catch {
        Write-LogMessage "Failed to verify Chezmoi installation: $($_.Exception.Message.Trim())" -Level Error
        return $false
    }
}

function Invoke-ChezmoiSetup {
    <#
    .SYNOPSIS
        Opens a terminal window for Chezmoi setup.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Username
        The username to run as.
    .PARAMETER GitName
        Git username for Chezmoi.
    .PARAMETER GitEmail
        Git email for Chezmoi.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GitName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GitEmail
    )    
    
    $ChezmoiCommand = "chezmoi init --apply $GitName --promptString `"GitHub\ username=$GitName`" --promptString `"GitHub\ email=$GitEmail`""
    # Validate Bitwarden CLI is available before proceeding
    if ((Test-BitwardenAvailable -DistroName $DistroName)) {
        Write-LogMessage "Bitwarden CLI (bw) is available." -Level Info
        $ChezmoiCommand = "export BW_SESSION=`$(bw login --raw) && chezmoi init --apply $GitName --promptString `"GitHub\ username=$GitName`" --promptString `"GitHub\ email=$GitEmail`""
    }

    Write-LogMessage "Starting Windows Terminal with Chezmoi setup" -Level Info
    Write-LogMessage "Chezmoi command: $ChezmoiCommand" -Level Debug
    Write-Host ""
    
    Invoke-WSLCommandInteractive -DistroName $DistroName -Command $ChezmoiCommand -Username $Username
    
    Write-LogMessage "Chezmoi terminal completed" -Level Success
}

# Export functions
Export-ModuleMember -Function Get-GitConfig, Test-ChezmoiInstallation, Invoke-ChezmoiSetup