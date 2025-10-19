# ============================================================================
# WSL Package Manager Module
# ============================================================================

<#
.SYNOPSIS
    Provides package management functions for WSL distributions.

.DESCRIPTION
    This module contains functions for initializing pacman, managing packages,
    and checking package manager status.

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
# Package Management Functions
# ============================================================================

function Initialize-PacmanKeyring {
    <#
    .SYNOPSIS
        Initializes the pacman keyring.
    .PARAMETER DistroName
        The name of the WSL distribution.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    # Check if keyring is already initialized to avoid redundant operations
    try {
        $keyringInitialized = Test-PacmanKeyInitialized -DistroName $DistroName

        if ($keyringInitialized) {
            Write-LogMessage "Pacman keyring is already initialized for distribution '$DistroName' - skipping initialization" -Level Success
            return
        }

        Write-LogMessage "Pacman keyring not yet initialized for distribution '$DistroName' - proceeding with initialization..." -Level Info
    }
    catch {
        Write-LogMessage "Failed to check keyring initialization status for distribution '$DistroName': $($_.Exception.Message.Trim())" -Level Warning
        Write-LogMessage "Proceeding with initialization to ensure keyring is properly set up" -Level Warning
    }
    
    Write-LogMessage "Initializing pacman keyring..." -Level Info
    
    try {
        $OutputRedirect = Get-OutputRedirection
        
        # Initialize keyring
        $Command = "pacman-key --init$OutputRedirect"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        Test-WSLExitCode -Operation "Pacman keyring initialization"
        Write-LogMessage "Pacman keyring initialized successfully" -Level Success
        
        # Populate Arch Linux keys
        Write-LogMessage "Populating Arch Linux keys..." -Level Info
        $Command = "pacman-key --populate archlinux$OutputRedirect"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        Test-WSLExitCode -Operation "Arch Linux keys population"
        Write-LogMessage "Arch Linux keys populated successfully" -Level Success
    }
    catch {
        Write-LogMessage "Failed to initialize pacman keyring: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

function Install-PacmanPackage {
    <#
    .SYNOPSIS
        Installs a single package using pacman.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER PackageName
        The name of the package to install.
    .OUTPUTS
        [bool] True if installation succeeded, false otherwise.
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
    
    Write-LogMessage "Installing package: $PackageName" -Level Info
    
    try {
        $OutputRedirect = Get-OutputRedirection
        $Command = "pacman -S $PackageName --noconfirm --needed --quiet$OutputRedirect"
        
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "Successfully installed package: $PackageName" -Level Success
            return $true
        }
        else {
            Write-LogMessage "Failed to install package: $PackageName" -Level Error
            return $false
        }
    }
    catch {
        Write-LogMessage "Error installing package '$PackageName': $($_.Exception.Message.Trim())" -Level Error
        return $false
    }
}

function Get-MissingPackages {
    <#
    .SYNOPSIS
        Identifies which packages from a list are not installed.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER PackageNames
        Array of package names to check.
    .OUTPUTS
        [string[]] Array of missing package names.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [string[]]$PackageNames
    )
    
    $MissingPackages = @()
    
    foreach ($Package in $PackageNames) {
        Write-LogMessage "Checking if package '$Package' is installed..." -Level Info
        
        if (-not (Test-PackageInstalled -DistroName $DistroName -PackageName $Package)) {
            Write-LogMessage "Package '$Package' is not installed" -Level Warning
            $MissingPackages += $Package
        }
        else {
            Write-LogMessage "Package '$Package' is installed" -Level Success
        }
    }
    
    return $MissingPackages
}

function Install-MissingPackages {
    <#
    .SYNOPSIS
        Installs all missing packages from a list.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER PackageNames
        Array of package names to install if missing.
    .OUTPUTS
        [bool] True if all packages installed successfully, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [string[]]$PackageNames
    )
    
    $MissingPackages = Get-MissingPackages -DistroName $DistroName -PackageNames $PackageNames
    
    if ($MissingPackages.Count -eq 0) {
        Write-LogMessage "All required packages are already installed" -Level Success
        return $true
    }
    
    Write-LogMessage "Attempting to install $($MissingPackages.Count) missing package(s)..." -Level Info
    $AllSucceeded = $true
    
    foreach ($Package in $MissingPackages) {
        $Result = Install-PacmanPackage -DistroName $DistroName -PackageName $Package
        if (-not $Result) {
            $AllSucceeded = $false
        }
    }
    
    return $AllSucceeded
}

function Initialize-PackageManager {
    <#
    .SYNOPSIS
        Initializes pacman and installs required packages.
    .PARAMETER DistroName
        The name of the WSL distribution.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    Write-Section "Initializing Package Manager"
    
    $OutputRedirect = Get-OutputRedirection
    
    # Initialize pacman keyring
    Initialize-PacmanKeyring -DistroName $DistroName
    
    # Update system packages
    try {
        Write-LogMessage "Updating system packages..." -Level Info
        $Command = "pacman -Syu --noconfirm --quiet$OutputRedirect"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        Write-LogMessage "System packages updated successfully" -Level Success
        Write-Host ""
    }
    catch {
        Write-LogMessage "System update failed: $($_.Exception.Message.Trim())" -Level Warning
    }
    
    # Install required packages
    Write-LogMessage "Installing required packages..." -Level Info
    $Result = Install-MissingPackages -DistroName $DistroName -PackageNames $script:PackageManagerPackages
    
    if ($Result) {
        Write-LogMessage "All required packages installed successfully" -Level Success
    }
    else {
        Write-LogMessage "Some packages failed to install" -Level Warning
    }
    
    Write-LogMessage "Package manager initialization complete" -Level Success
}

function Test-PackageManagerInitialized {
    <#
    .SYNOPSIS
        Checks if the package manager is fully initialized.
    .DESCRIPTION
        Verifies that sudo is available, pacman keyring is initialized,
        and required packages are installed.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .OUTPUTS
        [hashtable] Status object with initialization details.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    Write-LogMessage "Checking package manager initialization..." -Level Info
    
    $Status = @{
        SudoAvailable = $false
        KeyringInitialized = $false
        AllPackagesInstalled = $false
        MissingPackages = @()
    }
    
    # Check if the default user can use sudo
    try {
        if (Test-UserExists -DistroName $DistroName -Username $script:DefaultUsername) {
            $SudoAccess = Test-UserSudoAccess -DistroName $DistroName -Username $script:DefaultUsername
            if ($SudoAccess) {
                $Status.SudoAvailable = $true
                Write-LogMessage "Default user '$($script:DefaultUsername)' can use sudo" -Level Success
            }
            else {
                Write-LogMessage "Default user '$($script:DefaultUsername)' cannot use sudo" -Level Warning
                return $Status
            }
        }
        else {
            Write-LogMessage "Default user '$($script:DefaultUsername)' does not exist" -Level Warning
            return $Status
        }
    }
    catch {
        Write-LogMessage "Failed to check sudo access for default user" -Level Warning
        return $Status
    }
    
    # Check keyring initialization
    $Status.KeyringInitialized = Test-PacmanKeyInitialized -DistroName $DistroName
    
    if (-not $Status.KeyringInitialized) {
        Write-LogMessage "Pacman keyring is not initialized" -Level Warning
        return $Status
    }
    
    Write-LogMessage "Pacman keyring is initialized" -Level Success
    
    # Check required packages
    $Status.MissingPackages = Get-MissingPackages -DistroName $DistroName -PackageNames $script:PackageManagerPackages
    $Status.AllPackagesInstalled = ($Status.MissingPackages.Count -eq 0)
    
    if ($Status.AllPackagesInstalled) {
        Write-LogMessage "All required packages are installed" -Level Success
    }
    else {
        Write-LogMessage "Missing packages: $($Status.MissingPackages -join ', ')" -Level Warning
    }
    
    return $Status
}

# Export functions
Export-ModuleMember -Function Initialize-PacmanKeyring, Install-PacmanPackage, 
                              Get-MissingPackages, Install-MissingPackages, 
                              Initialize-PackageManager, Test-PackageManagerInitialized