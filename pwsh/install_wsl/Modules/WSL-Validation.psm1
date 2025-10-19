# ============================================================================
# WSL Validation Module
# ============================================================================

<#
.SYNOPSIS
    Provides validation functions for WSL installation scripts.

.DESCRIPTION
    This module contains functions for validating usernames, checking
    system availability, and testing WSL distribution status.

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
# Validation Functions
# ============================================================================

function Test-ValidLinuxUsername {
    <#
    .SYNOPSIS
        Validates that a username meets Linux requirements.
    .DESCRIPTION
        Checks if username starts with lowercase letter or underscore,
        contains only valid characters, and is within length limits.
    .PARAMETER Username
        The username to validate.
    .OUTPUTS
        [bool] True if valid, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Username
    )
    
    # Linux username requirements: lowercase letters, numbers, underscore, hyphen
    # Must start with lowercase letter or underscore
    # Max 32 characters
    if ($Username -notmatch '^[a-z_][a-z0-9_-]{0,31}$') {
        return $false
    }
    
    return $true
}

function Test-GitAvailable {
    <#
    .SYNOPSIS
        Checks if git is available in the system PATH.
    .OUTPUTS
        [bool] True if git is available, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    try {
        $null = Get-Command git -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-DistributionExists {
    <#
    .SYNOPSIS
        Checks if a WSL distribution exists.
    .PARAMETER DistroName
        The name of the distribution to check.
    .OUTPUTS
        [bool] True if distribution exists, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    Write-LogMessage "Checking if WSL distribution '$DistroName' exists" -Level Debug
    
    try {
        $Distributions = wsl --list --quiet 2>$null | Out-String
        
        if (-not [string]::IsNullOrWhiteSpace($Distributions)) {
            $DistributionList = $Distributions -split "`r?`n" | Where-Object { $_ -and $_.Trim() }
            
            foreach ($Distro in $DistributionList) {
                $CleanDistro = Format-WSLOutput -Output $Distro
                
                if ($CleanDistro -eq $DistroName) {
                    Write-LogMessage "Distribution '$DistroName' exists" -Level Debug
                    return $true
                }
            }
        }
        
        Write-LogMessage "Distribution '$DistroName' does not exist" -Level Debug
        return $false
    }
    catch {
        Write-LogMessage "Error checking if distribution exists: $($_.Exception.Message.Trim())" -Level Error
        return $false
    }
}

function Test-DistributionReady {
    <#
    .SYNOPSIS
        Tests if a WSL distribution is ready for commands.
    .PARAMETER DistroName
        The name of the distribution to test.
    .OUTPUTS
        [bool] True if ready, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    # Pre-condition validation: Check if distribution exists first
    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        Write-LogMessage "Cannot test readiness - distribution '$DistroName' does not exist" -Level Warning
        return $false
    }
    
    try {
        $Result = wsl -d $DistroName -u root -- echo "ready" 2>&1 | Out-String
        
        # Ensure we return a boolean value
        if ([string]::IsNullOrWhiteSpace($Result)) {
            return $false
        }
        
        return $Result -match "ready"
    }
    catch {
        return $false
    }
}

function Test-UserExists {
    <#
    .SYNOPSIS
        Checks if a user exists in the WSL distribution.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Username
        The username to check.
    .OUTPUTS
        [bool] True if user exists, false otherwise.
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
    
    # Pre-condition validation: Check if distribution exists first
    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        Write-LogMessage "Cannot check user '$Username' - distribution '$DistroName' does not exist" -Level Warning
        return $false
    }
    
    try {
        $Command = "id $Username >/dev/null 2>&1 && echo 'exists' || echo 'not_found'"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot
        
        # Ensure we return a boolean value
        if ([string]::IsNullOrWhiteSpace($Result)) {
            return $false
        }
        
        return $Result -match "exists"
    }
    catch {
        Write-LogMessage "Error checking if user exists: $($_.Exception.Message.Trim())" -Level Warning
        return $false
    }
}

function Test-UserSudoAccess {
    <#
    .SYNOPSIS
        Tests if a user can use sudo without password prompts.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Username
        The username to test.
    .OUTPUTS
        [bool] True if user has passwordless sudo, false otherwise.
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
    
    # Pre-condition validation: Check if distribution exists and user exists first
    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        Write-LogMessage "Cannot check sudo access for user '$Username' - distribution '$DistroName' does not exist" -Level Warning
        return $false
    }
    
    if (-not (Test-UserExists -DistroName $DistroName -Username $Username)) {
        Write-LogMessage "Cannot check sudo access - user '$Username' does not exist in distribution '$DistroName'" -Level Warning
        return $false
    }
    
    try {
        $Command = "sudo -n whoami"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -Username $Username
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Test-PacmanKeyInitialized {
    <#
    .SYNOPSIS
        Uses pacman-key to test if the pacman keyring is initialized for a WSL distribution.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .OUTPUTS
        [bool] True if initialized, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        Write-LogMessage "Distro '$DistroName' does not exist; skipping pacman-key initialization check." -Level Warning
        return $false
    }

    try {
        # Use pacman-key to list keys and check if the keyring is initialized
        $Command = "pacman-key --list-keys >/dev/null 2>&1 && echo 'initialized' || echo 'not_initialized'"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot
        
        # Ensure we return a boolean value
        if ([string]::IsNullOrWhiteSpace($Result)) {
            return $false
        }
        
        return $Result -match "initialized"
    }
    catch {
        Write-LogMessage "Error checking pacman-key initialization: $($_.Exception.Message.Trim())" -Level Warning
        return $false
    }
}

function Test-PackageInstalled {
    <#
    .SYNOPSIS
        Checks if a package is installed using pacman.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER PackageName
        The name of the package to check.
    .OUTPUTS
        [bool] True if installed, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageName
    )

    # Pre-condition validation: Check if distribution exists first
    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        Write-LogMessage "Cannot check package '$PackageName' - distribution '$DistroName' does not exist" -Level Warning
        return $false
    }

    try {
        $null = Invoke-WSLCommand -DistroName $DistroName -Command "pacman -Qi $PackageName" -AsRoot -Quiet
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-Chezmoi {
    <#
    .SYNOPSIS
        Checks if the chezmoi command is available on WSL.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .OUTPUTS
        [bool] True if chezmoi is available, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    # Pre-condition validation: Check if distribution exists first
    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        Write-LogMessage "Cannot check chezmoi availability - distribution '$DistroName' does not exist" -Level Warning
        return $false
    }
    
    try {
        $Command = "command -v chezmoi >/dev/null 2>&1 && echo 'available' || echo 'not_available'"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot
        
        # Ensure we return a boolean value
        if ([string]::IsNullOrWhiteSpace($Result)) {
            return $false
        }
        
        return $Result -match "available"
    }
    catch {
        Write-LogMessage "Error checking chezmoi availability: $($_.Exception.Message.Trim())" -Level Warning
        return $false
    }
}

function Test-ChezmoiConfigured {
    <#
    .SYNOPSIS
        Checks if Chezmoi is already configured for the user.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Username
        The username to check.
    .OUTPUTS
        [bool] True if configured, false otherwise.
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
    
    # Pre-condition validation: Check if distribution exists and user exists first
    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        Write-LogMessage "Cannot check Chezmoi configuration for user '$Username' - distribution '$DistroName' does not exist" -Level Warning
        return $false
    }
    
    if (-not (Test-UserExists -DistroName $DistroName -Username $Username)) {
        Write-LogMessage "Cannot check Chezmoi configuration - user '$Username' does not exist in distribution '$DistroName'" -Level Warning
        return $false
    }
    
    try {
        $Command = "command -v chezmoi >/dev/null 2>&1 && test -d ~/.local/share/chezmoi && echo 'configured' || echo 'not_configured'"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -Username $Username
        
        # Ensure we return a boolean value
        if ([string]::IsNullOrWhiteSpace($Result)) {
            return $false
        }
        
        return $Result -match "configured"
    }
    catch {
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Test-ValidLinuxUsername, Test-GitAvailable, Test-DistributionExists,
                              Test-DistributionReady, Test-UserExists, Test-UserSudoAccess,
                              Test-PacmanKeyInitialized, Test-PackageInstalled, Test-Chezmoi, Test-ChezmoiConfigured
