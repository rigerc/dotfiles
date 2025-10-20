# ============================================================================
# WSL Management Module
# ============================================================================

<#
.SYNOPSIS
    Provides WSL distribution management functions.

.DESCRIPTION
    This module contains functions for installing, removing, and managing
    WSL distributions including waiting for them to be ready.

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
# WSL Management Functions
# ============================================================================

function Remove-WSLDistribution {
    <#
    .SYNOPSIS
        Removes an existing WSL distribution.
    .PARAMETER DistroName
        The name of the distribution to remove.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    Write-LogMessage "Removing existing WSL distribution: $DistroName" -Level Warning
    
    try {
        $Output = wsl --unregister $DistroName 2>&1
        Test-WSLExitCode -Operation "Distribution removal"
        Write-LogMessage "Successfully removed distribution: $DistroName" -Level Success
    }
    catch {
        Write-LogMessage "Failed to remove distribution: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

function Install-WSLDistribution {
    <#
    .SYNOPSIS
        Installs a new WSL distribution from image.
    .PARAMETER ImageName
        The name of the distribution image to install.
    .PARAMETER DistroName
        The name to assign to the installed distribution.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ImageName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    Write-LogMessage "Preparing to install WSL distribution: $DistroName from image: $ImageName" -Level Info
    
    # Remove existing distribution if present
    if (Test-DistributionExists -DistroName $DistroName) {
        Write-LogMessage "Distribution '$DistroName' already exists. Removing it first..." -Level Warning
        Remove-WSLDistribution -DistroName $DistroName
        Start-Sleep -Seconds 3
    }
    
    Write-LogMessage "Starting installation - this may take several minutes..." -Level Info
    
    try {
        $Output = wsl --install $ImageName --name $DistroName --no-launch
        Test-WSLExitCode -Operation "Distribution installation"
        Write-LogMessage "WSL distribution installation completed" -Level Success
    }
    catch {
        Write-LogMessage "Failed to install distribution: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

function Wait-ForDistributionReady {
    <#
    .SYNOPSIS
        Waits for WSL distribution to be fully ready with progress feedback.
    .PARAMETER DistroName
        The name of the distribution to wait for.
    .PARAMETER MaxAttempts
        Maximum number of attempts (default from constants).
    .PARAMETER DelaySeconds
        Delay between attempts (default from constants).
    .OUTPUTS
        [bool] True if distribution became ready, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [int]$MaxAttempts = $script:DistributionReadyMaxAttempts,
        [int]$DelaySeconds = $script:DistributionReadyDelaySeconds
    )
    
    $Activity = "Waiting for WSL Distribution '$DistroName' to be Ready"
    Write-LogMessage "Waiting for distribution to be ready..." -Level Info
    Start-Sleep(4)
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        $PercentComplete = [math]::Round(($i / $MaxAttempts) * 100)
        $SecondsRemaining = ($MaxAttempts - $i) * $DelaySeconds
        $Status = "Attempt $i of $MaxAttempts"
        
        Write-ProgressLog -Activity $Activity -Status $Status -PercentComplete $PercentComplete -SecondsRemaining $SecondsRemaining -CurrentOperation "Checking distribution status..."
        
        if (Test-DistributionReady -DistroName $DistroName) {
            # Verify bash is available
            try {
                $BashCheck = wsl -d $DistroName -u root -- bash -c "echo 'bash_ready'" 2>&1 | Out-String
                if ($BashCheck -match "bash_ready") {
                    Write-ProgressLog -Activity $Activity -Complete
                    Write-LogMessage "Distribution is ready after $i attempt(s)" -Level Success
                    return $true
                }
            }
            catch {
                Write-LogMessage "Bash verification failed, retrying..." -Level Warning
            }
        }
        
        if ($i -lt $MaxAttempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }
    
    Write-ProgressLog -Activity $Activity -Complete
    Write-LogMessage "Distribution did not become ready after $MaxAttempts attempts" -Level Error
    return $false
}

function Stop-WSLDistribution {
    <#
    .SYNOPSIS
        Terminates a running WSL distribution.
    .PARAMETER DistroName
        The name of the distribution to terminate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    Write-LogMessage "Shutting down WSL distribution: $DistroName" -Level Info
    
    try {
        $Output = wsl --terminate $DistroName 2>&1
        Test-WSLExitCode -Operation "Distribution termination"
        Write-LogMessage "WSL distribution shut down successfully" -Level Success
    }
    catch {
        Write-LogMessage "Failed to terminate distribution: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

function Set-WSLDefaultDistribution {
    <#
    .SYNOPSIS
        Sets a WSL distribution as the default.
    .PARAMETER DistroName
        The name of the distribution to set as default.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    Write-LogMessage "Setting '$DistroName' as the default WSL distribution..." -Level Info
    
    try {
        $Output = wsl --set-default $DistroName 2>&1
        Test-WSLExitCode -Operation "Setting default distribution"
        Write-LogMessage "'$DistroName' is now the default WSL distribution" -Level Success
    }
    catch {
        Write-LogMessage "Failed to set default distribution: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

# Export functions
Export-ModuleMember -Function Remove-WSLDistribution, Install-WSLDistribution,
                              Wait-ForDistributionReady, Stop-WSLDistribution,
                              Set-WSLDefaultDistribution