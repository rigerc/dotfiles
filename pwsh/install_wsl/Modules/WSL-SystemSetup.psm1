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
    
    # Install WSL feature
    try {
        Write-LogMessage "Checking for Windows Subsystem for Linux..." -Level Info
        $WslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
        
        if ($WslFeature.State -ne 'Enabled') {
            Write-LogMessage "Installing Windows Subsystem for Linux..." -Level Info
            $WslInstall = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
            
            if ($WslInstall.RestartNeeded) {
                Write-LogMessage "Windows Subsystem for Linux installation requires restart" -Level Warning
                $RebootRequired = $true
            }
            else {
                Write-LogMessage "Windows Subsystem for Linux installed successfully" -Level Success
            }
        }
        else {
            Write-LogMessage "Windows Subsystem for Linux already installed" -Level Info
        }
    }
    catch {
        Write-LogMessage "Failed to install Windows Subsystem for Linux: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
    
    # Install Virtual Machine Platform
    try {
        Write-LogMessage "Checking for Virtual Machine Platform..." -Level Info
        $VmpFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
        
        if ($VmpFeature.State -ne 'Enabled') {
            Write-LogMessage "Installing Virtual Machine Platform..." -Level Info
            $VmpInstall = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform
            
            if ($VmpInstall.RestartNeeded) {
                Write-LogMessage "Virtual Machine Platform installation requires restart" -Level Warning
                $RebootRequired = $true
            }
            else {
                Write-LogMessage "Virtual Machine Platform installed successfully" -Level Success
            }
        }
        else {
            Write-LogMessage "Virtual Machine Platform already installed" -Level Info
        }
    }
    catch {
        Write-LogMessage "Failed to install Virtual Machine Platform: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
    
    # Update WSL kernel
    try {
        Write-LogMessage "Updating WSL kernel..." -Level Info
        $null = wsl --update 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "WSL kernel updated successfully" -Level Success
        }
        else {
            Write-LogMessage "WSL kernel update completed with warnings" -Level Warning
        }
    }
    catch {
        Write-LogMessage "WSL kernel update failed: $($_.Exception.Message.Trim())" -Level Warning
    }
    
    # Set WSL2 as default
    try {
        Write-LogMessage "Setting WSL2 as default version..." -Level Info
        $null = wsl --set-default-version 2 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "WSL2 set as default version" -Level Success
        }
        else {
            Write-LogMessage "WSL2 set as default with warnings" -Level Warning
        }
    }
    catch {
        Write-LogMessage "Failed to set WSL2 as default: $($_.Exception.Message.Trim())" -Level Warning
    }
    
    if ($RebootRequired) {
        Write-LogMessage "WSL feature installation completed - restart required" -Level Warning
    }
    else {
        Write-LogMessage "WSL feature installation completed successfully" -Level Success
    }
    
    return $RebootRequired
}

# Export functions
Export-ModuleMember -Function Install-WSLFeatures