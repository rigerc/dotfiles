# ============================================================================
# WSL Workflow Module
# ============================================================================

<#
.SYNOPSIS
    Provides workflow orchestration functions for WSL installation.

.DESCRIPTION
    This module contains functions for coordinating the main installation workflows,
    including continue mode, normal mode, Chezmoi setup, and completion summaries.

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
# Continue Mode Functions
# ============================================================================

function Invoke-ContinueChecks {
    <#
    .SYNOPSIS
        Performs all necessary checks when Continue mode is used.
    .DESCRIPTION
        Verifies distribution exists and checks initialization status of
        package manager, user, and Chezmoi configuration.
    .PARAMETER DistroName
        The name of the distribution to check.
    .PARAMETER Username
        The username to check.
    .PARAMETER UseChezmoi
        Whether to check Chezmoi configuration.
    .OUTPUTS
        [hashtable] Status object with check results.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,
        
        [bool]$UseChezmoi
    )
    
    Write-Section "Continue Mode - Checking Distribution Status"
    
    # Check if distribution exists
    Write-LogMessage "Verifying distribution '$DistroName' exists..." -Level Info
    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        throw "Distribution '$DistroName' does not exist. Cannot use Continue mode."
    }
    Write-LogMessage "Distribution '$DistroName' exists" -Level Success
    
    # Check if distribution is ready
    Write-LogMessage "Checking if distribution '$DistroName' is ready..." -Level Info
    if (-not (Wait-ForDistributionReady -DistroName $DistroName)) {
        throw "Distribution '$DistroName' is not ready. Cannot proceed."
    }
    Write-LogMessage "Distribution '$DistroName' is ready" -Level Success
    
    # Check package manager initialization
    $PackageManagerStatus = Test-PackageManagerInitialized -DistroName $DistroName
    
    # Check if user exists
    $UserExists = Test-UserExists -DistroName $DistroName -Username $Username
    
    # Check if Chezmoi is configured (if requested)
    $ChezmoiConfigured = $false
    if ($UseChezmoi -and $UserExists) {
        $ChezmoiConfigured = Test-ChezmoiConfigured -DistroName $DistroName -Username $Username
    }
    
    # Return status object
    return @{
        PackageManagerStatus = $PackageManagerStatus
        UserExists = $UserExists
        ChezmoiConfigured = $ChezmoiConfigured
    }
}

# ============================================================================
# Main Workflow Functions
# ============================================================================

function Invoke-ContinueModeWorkflow {
    <#
    .SYNOPSIS
        Executes the Continue mode workflow.
    .PARAMETER Config
        Configuration hashtable with user settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    Write-Section "Continue Mode - Checking Existing Distribution"
    
    # Perform Continue checks
    $Status = Invoke-ContinueChecks -DistroName $Config.DistroName -Username $Config.Username -UseChezmoi $Config.UseChezmoi
    
    # Handle package manager initialization
    $PackageManagerReady = $Status.PackageManagerStatus.SudoAvailable -and 
                          $Status.PackageManagerStatus.KeyringInitialized -and 
                          $Status.PackageManagerStatus.AllPackagesInstalled
    
    if (-not $PackageManagerReady) {
        Write-LogMessage "Package manager not fully initialized" -Level Warning
        
        # Try to install missing packages first
        if ($Status.PackageManagerStatus.MissingPackages.Count -gt 0) {
            Write-LogMessage "Installing missing packages..." -Level Info
            $Result = Install-MissingPackages -DistroName $Config.DistroName -PackageNames $Status.PackageManagerStatus.MissingPackages
            
            if (-not $Result) {
                Write-LogMessage "Failed to install some packages - running full initialization..." -Level Warning
                Initialize-PackageManager -DistroName $Config.DistroName
            }
        }
        else {
            Write-LogMessage "Running full package manager initialization..." -Level Info
            Initialize-PackageManager -DistroName $Config.DistroName
        }
    }
    else {
        Write-LogMessage "Package manager already initialized - skipping" -Level Success
    }
    
    # Handle user creation
    if (-not $Status.UserExists) {
        Write-LogMessage "User does not exist - creating user..." -Level Warning
        New-WSLUser -DistroName $Config.DistroName -Username $Config.Username
        Add-UserToSudoers -DistroName $Config.DistroName -Username $Config.Username
    }
    else {
        Write-LogMessage "User already exists - checking sudo access..." -Level Success
        
        if (-not (Test-UserSudoAccess -DistroName $Config.DistroName -Username $Config.Username)) {
            Write-LogMessage "User exists but sudo access not working - configuring sudo..." -Level Warning
            Add-UserToSudoers -DistroName $Config.DistroName -Username $Config.Username
        }
        else {
            Write-LogMessage "User exists with working sudo access" -Level Success
        }
    }
    
    # Verify configuration
    Test-Configuration -DistroName $Config.DistroName -Username $Config.Username
    Restart-WSLDistribution -DistroName $Config.DistroName
}

function Invoke-NormalModeWorkflow {
    <#
    .SYNOPSIS
        Executes the normal mode workflow (fresh installation).
    .PARAMETER Config
        Configuration hashtable with user settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    Write-Section "Starting WSL Distribution Setup"
    
    # Install the distribution
    Install-WSLDistribution -ImageName $Config.DistroImage -DistroName $Config.DistroName
    
    # Verify distribution was registered
    Write-LogMessage "Verifying distribution registration..." -Level Info
    if (-not (Test-DistributionExists -DistroName $Config.DistroName)) {
        throw "Distribution was not successfully registered with WSL"
    }
    Write-LogMessage "Distribution registered successfully" -Level Success
    
    # Wait for distribution to be ready
    Write-LogMessage "Checking distribution readiness..." -Level Info
    if (-not (Wait-ForDistributionReady -DistroName $Config.DistroName)) {
        throw "Distribution failed to become ready"
    }
    
    # Initialize package manager
    Initialize-PackageManager -DistroName $Config.DistroName
    
    # Create user and configure sudo
    New-WSLUser -DistroName $Config.DistroName -Username $Config.Username
    Add-UserToSudoers -DistroName $Config.DistroName -Username $Config.Username
    
    # Verify configuration
    Test-Configuration -DistroName $Config.DistroName -Username $Config.Username
    Restart-WSLDistribution -DistroName $Config.DistroName
}

function Invoke-ChezmoiWorkflow {
    <#
    .SYNOPSIS
        Executes the Chezmoi setup workflow.
    .PARAMETER Config
        Configuration hashtable with user settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    if (-not $Config.UseChezmoi) {
        return
    }
    
    Start-Sleep -Seconds 5
    Write-LogMessage "Opening Chezmoi terminal. Script will pause until you complete the setup and close the terminal." -Level Info
    
    Invoke-ChezmoiSetup -DistroName $Config.DistroName -Username $Config.Username -GitName $Config.GitName -GitEmail $Config.GitEmail
    
    Write-LogMessage "Chezmoi terminal has been closed. Continuing with script execution." -Level Info
    
    # Verify Chezmoi installation
    if (-not (Test-ChezmoiInstallation -DistroName $Config.DistroName -Username $Config.Username)) {
        Write-LogMessage "Chezmoi installation verification failed. Stopping script execution." -Level Error
        throw "Chezmoi installation verification failed"
    }
    
    Start-Sleep -Seconds 3
    
}

function Show-CompletionSummary {
    <#
    .SYNOPSIS
        Displays the final completion summary.
    .PARAMETER Config
        Configuration hashtable with user settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    Write-Section "Setup Complete!"
    Write-Host "Your WSL ArchLinux distribution is ready." -ForegroundColor Green
    Write-Host "Distribution Name: " -ForegroundColor White -NoNewline
    Write-Host $Config.DistroName -ForegroundColor Cyan
    Write-Host "Username:          " -ForegroundColor White -NoNewline
    Write-Host $Config.Username -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To connect to your distribution, use:" -ForegroundColor Yellow
    Write-Host "  wsl -d $($Config.DistroName) -u $($Config.Username)" -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    # Ask if user wants to set this distribution as default
    Write-Host "Would you like to set '$($Config.DistroName)' as your default WSL distribution?" -ForegroundColor Yellow
    Write-Host "This will make it open automatically when you run 'wsl' without parameters." -ForegroundColor Gray
    $SetDefault = Read-Host "Set as default? (Y/n)"
    
    if ($SetDefault -ne 'n' -and $SetDefault -ne 'N') {
        try {
            Set-WSLDefaultDistribution -DistroName $Config.DistroName
            Write-Host "Default distribution set successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to set default distribution: $($_.Exception.Message)" -ForegroundColor Red
            Write-LogMessage "Failed to set default distribution: $($_.Exception.Message)" -Level Warning
        }
    }
    else {
        Write-Host "Default distribution not changed." -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-LogMessage "Setup completed successfully" -Level Success
}

# Export functions
Export-ModuleMember -Function Invoke-ContinueChecks, Invoke-ContinueModeWorkflow,
                              Invoke-NormalModeWorkflow, Invoke-ChezmoiWorkflow,
                              Show-CompletionSummary