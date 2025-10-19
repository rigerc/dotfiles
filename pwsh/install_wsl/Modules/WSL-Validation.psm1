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
    Write-LogMessage "Executing command: wsl --list --quiet" -Level Debug
    
    try {
        $Distributions = wsl --list --quiet 2>$null | Out-String
        Write-LogMessage "WSL command executed with exit code: $LASTEXITCODE" -Level Debug
        
        if ($Distributions) {
            Write-LogMessage "WSL distributions found: $($Distributions.Replace("`n", ', ').Trim())" -Level Debug
            $DistributionList = $Distributions -split "`r?`n"
            Write-LogMessage "Processing $($DistributionList.Count) distribution entries" -Level Debug
            
            foreach ($Distro in $DistributionList) {
                Write-LogMessage "Processing distribution entry: '$Distro'" -Level Debug
                $CleanDistro = Format-WSLOutput -Output $Distro
                Write-LogMessage "Cleaned distribution name: '$CleanDistro'" -Level Debug
                
                if ($CleanDistro -eq $DistroName) {
                    Write-LogMessage "Match found! Distribution '$DistroName' exists" -Level Debug
                    return $true
                }
                else {
                    Write-LogMessage "No match. '$CleanDistro' != '$DistroName'" -Level Debug
                }
            }
            Write-LogMessage "No match found for distribution '$DistroName' after checking all entries" -Level Debug
        }
        else {
            Write-LogMessage "No WSL distributions found or WSL command returned empty output" -Level Debug
        }
        
        Write-LogMessage "Returning false - distribution '$DistroName' does not exist" -Level Debug
        return $false
    }
    catch {
        Write-LogMessage "Error checking if distribution exists: $($_.Exception.Message.Trim())" -Level Error
        Write-LogMessage "Exception type: $($_.Exception.GetType().Name)" -Level Debug
        Write-LogMessage "Returning false due to exception" -Level Debug
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
    
    try {
        $Result = wsl -d $DistroName -u root -- echo "ready" 2>&1 | Out-String
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
    
    try {
        $Command = "id $Username >/dev/null 2>&1 && echo 'exists' || echo 'not_found'"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
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
    
    try {
        $Command = "sudo -n whoami"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -Username $Username -Quiet
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Test-PacmanKeyringInitialized {
    <#
    .SYNOPSIS
        Checks if the pacman keyring is initialized.
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
    
    try {
        $Command = "test -d /etc/pacman.d/gnupg && (ls -A /etc/pacman.d/gnupg 2>/dev/null | grep -q .) && echo 'initialized' || echo 'not_initialized'"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        return $Result -match "initialized"
    }
    catch {
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
 
    
    try {
        $Command = "pacman -Qi $PackageName >/dev/null 2>&1 && echo 'installed' || echo 'not_installed'"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        return $Result -match "installed"
    }
    catch {
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
    
    try {
        $Command = "command -v chezmoi >/dev/null 2>&1 && test -d ~/.local/share/chezmoi && echo 'configured' || echo 'not_configured'"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -Username $Username -Quiet
        return $Result -match "configured"
    }
    catch {
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Test-ValidLinuxUsername, Test-GitAvailable, Test-DistributionExists, 
                              Test-DistributionReady, Test-UserExists, Test-UserSudoAccess, 
                              Test-PacmanKeyringInitialized, Test-PackageInstalled, Test-ChezmoiConfigured