# ============================================================================
# WSL System Setup Module
# ============================================================================

<#
.SYNOPSIS
    Provides WSL system component installation functions.

.DESCRIPTION
    This module contains functions for installing WSL features,
    updating the WSL kernel, and setting WSL2 as default.

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
# WSL System Setup Functions
# ============================================================================

function Install-WSLFeatures {
    <#
    .SYNOPSIS
        Installs required Windows features for WSL.
    .DESCRIPTION
        Installs Windows Subsystem for Linux and Virtual Machine Platform features,
        updates WSL kernel, and sets WSL2 as the default version.
    .OUTPUTS
        [bool] True if reboot is required, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $RebootRequired = $false
    $FeaturesInstalled = @()

    # Install WSL feature
    try {
        $WslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

        if ($WslFeature.State -ne 'Enabled') {
            $WslInstall = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
            if ($WslInstall.RestartNeeded) {
                $RebootRequired = $true
            }
            $FeaturesInstalled += "Windows Subsystem for Linux"
        }
    }
    catch {
        Write-LogMessage "Failed to install Windows Subsystem for Linux: $($_.Exception.Message.Trim())" -Level Error
        throw
    }

    # Install Virtual Machine Platform
    try {
        $VmpFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

        if ($VmpFeature.State -ne 'Enabled') {
            $VmpInstall = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform
            if ($VmpInstall.RestartNeeded) {
                $RebootRequired = $true
            }
            $FeaturesInstalled += "Virtual Machine Platform"
        }
    }
    catch {
        Write-LogMessage "Failed to install Virtual Machine Platform: $($_.Exception.Message.Trim())" -Level Error
        throw
    }

    # Update WSL kernel
    try {
        $null = wsl --update 2>&1
    }
    catch {
        Write-LogMessage "WSL kernel update failed: $($_.Exception.Message.Trim())" -Level Warning
    }

    # Set WSL2 as default
    try {
        $null = wsl --set-default-version 2 2>&1
    }
    catch {
        Write-LogMessage "Failed to set WSL2 as default: $($_.Exception.Message.Trim())" -Level Warning
    }

    # Report results
    if ($FeaturesInstalled.Count -gt 0) {
        if ($RebootRequired) {
            Write-LogMessage "WSL features installed - restart required" -Level Warning
        }
        else {
            Write-LogMessage "WSL features installed successfully" -Level Success
        }
    }
    else {
        Write-LogMessage "WSL features already configured" -Level Success
    }

    return $RebootRequired
}

# Export functions
Export-ModuleMember -Function Install-WSLFeatures