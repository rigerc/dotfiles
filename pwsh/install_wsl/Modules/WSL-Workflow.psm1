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

    Write-Section "Checking Existing Distribution"

    # Check if distribution exists and is ready
    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        throw "Distribution '$DistroName' does not exist. Cannot use Continue mode."
    }
    if (-not (Wait-ForDistributionReady -DistroName $DistroName)) {
        throw "Distribution '$DistroName' is not ready. Cannot proceed."
    }

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

    Write-Section "Configuring Existing Distribution"

    # Perform Continue checks
    $Status = Invoke-ContinueChecks -DistroName $Config.DistroName -Username $Config.Username -UseChezmoi $Config.UseChezmoi

    # Handle package manager initialization
    $PackageManagerReady = $Status.PackageManagerStatus.SudoAvailable -and
                          $Status.PackageManagerStatus.KeyringInitialized -and
                          $Status.PackageManagerStatus.AllPackagesInstalled

    if (-not $PackageManagerReady) {
        Write-LogMessage "Initializing package manager..." -Level Info

        # Try to install missing packages first
        if ($Status.PackageManagerStatus.MissingPackages.Count -gt 0) {
            $Result = Install-MissingPackages -DistroName $Config.DistroName -PackageNames $Status.PackageManagerStatus.MissingPackages

            if (-not $Result) {
                Initialize-PackageManager -DistroName $Config.DistroName
            }
        }
        else {
            Initialize-PackageManager -DistroName $Config.DistroName
        }
        Write-LogMessage "Package manager initialized" -Level Success
    }

    # Handle user creation
    if (-not $Status.UserExists) {
        Write-LogMessage "Creating user '$($Config.Username)'..." -Level Info
        New-WSLUser -DistroName $Config.DistroName -Username $Config.Username
        Add-UserToSudoers -DistroName $Config.DistroName -Username $Config.Username
        Write-LogMessage "User created with sudo access" -Level Success
    }
    else {
        if (-not (Test-UserSudoAccess -DistroName $Config.DistroName -Username $Config.Username)) {
            Write-LogMessage "Configuring sudo access for existing user..." -Level Info
            Add-UserToSudoers -DistroName $Config.DistroName -Username $Config.Username
            Write-LogMessage "Sudo access configured" -Level Success
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

    Write-Section "Installing WSL Distribution"
    Write-ProgressLog -Activity "WSL Setup" -Status "Installing ArchLinux distribution" -PercentComplete 25

    # Install the distribution
    Install-WSLDistribution -ImageName $Config.DistroImage -DistroName $Config.DistroName

    # Verify distribution was registered and ready
    if (-not (Test-DistributionExists -DistroName $Config.DistroName)) {
        throw "Distribution was not successfully registered with WSL"
    }
    if (-not (Wait-ForDistributionReady -DistroName $Config.DistroName)) {
        throw "Distribution failed to become ready"
    }

    Write-LogMessage "Distribution '$($Config.DistroName)' installed successfully" -Level Success
    Write-ProgressLog -Activity "WSL Setup" -Status "Configuring system" -PercentComplete 50

    # Initialize package manager
    Initialize-PackageManager -DistroName $Config.DistroName

    Write-ProgressLog -Activity "WSL Setup" -Status "Creating user account" -PercentComplete 75

    # Create user and configure sudo
    New-WSLUser -DistroName $Config.DistroName -Username $Config.Username
    Add-UserToSudoers -DistroName $Config.DistroName -Username $Config.Username

    Write-LogMessage "User '$($Config.Username)' created with sudo access" -Level Success
    Write-ProgressLog -Activity "WSL Setup" -Status "Finalizing setup" -PercentComplete 100 -Complete

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
        Write-LogMessage "Chezmoi installation verification failed" -Level Warning
        Write-Host ""
        Write-Host "Chezmoi verification failed. Some targets may not match their expected state." -ForegroundColor Yellow
        Write-Host "Would you like to:" -ForegroundColor White
        Write-Host "1. Rerun Chezmoi setup" -ForegroundColor Cyan
        Write-Host "2. Continue without verification" -ForegroundColor Yellow
        Write-Host "3. Stop the script" -ForegroundColor Red
        Write-Host ""
        
        $Choice = Read-Host "Enter your choice (1-3)"
        
        switch ($Choice) {
            "1" {
                Write-LogMessage "Rerunning Chezmoi setup..." -Level Info
                Invoke-ChezmoiSetup -DistroName $Config.DistroName -Username $Config.Username -GitName $Config.GitName -GitEmail $Config.GitEmail
                Write-LogMessage "Chezmoi terminal has been closed. Verifying installation again..." -Level Info
                Start-Sleep -Seconds 3
                
                # Verify again after rerunning setup
                if (-not (Test-ChezmoiInstallation -DistroName $Config.DistroName -Username $Config.Username)) {
                    Write-LogMessage "Chezmoi installation verification failed after rerunning setup. Stopping script execution." -Level Error
                    throw "Chezmoi installation verification failed"
                }
                Write-LogMessage "Chezmoi installation verified successfully after rerunning setup" -Level Success
            }
            "2" {
                Write-LogMessage "Continuing without Chezmoi verification as requested by user" -Level Warning
            }
            "3" {
                Write-LogMessage "Stopping script execution as requested by user" -Level Error
                throw "Chezmoi installation verification failed - stopped by user"
            }
            default {
                Write-LogMessage "Invalid choice. Stopping script execution." -Level Error
                throw "Chezmoi installation verification failed - invalid user choice"
            }
        }
    }
    else {
        Write-LogMessage "Chezmoi installation verified successfully" -Level Success
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

    Write-Section "Complete!"
    Write-Host "✅ WSL ArchLinux setup completed successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Distribution: $($Config.DistroName)" -ForegroundColor White
    Write-Host "Username:     $($Config.Username)" -ForegroundColor White
    Write-Host ""
    Write-Host "Connect with:" -ForegroundColor Gray
    Write-Host "  wsl -d $($Config.DistroName) -u $($Config.Username)" -ForegroundColor Cyan
    Write-Host ""

    # Ask if user wants to set this distribution as default
    Write-Host "Set '$($Config.DistroName)' as default WSL distribution? (Y/n)" -ForegroundColor Yellow
    $SetDefault = Read-Host

    if ($SetDefault -ne 'n' -and $SetDefault -ne 'N') {
        try {
            Set-WSLDefaultDistribution -DistroName $Config.DistroName
            Write-LogMessage "Default distribution set" -Level Success
        }
        catch {
            Write-LogMessage "Failed to set default distribution: $($_.Exception.Message)" -Level Warning
        }
    }
}

# Export functions
Export-ModuleMember -Function Invoke-ContinueChecks, Invoke-ContinueModeWorkflow,
                              Invoke-NormalModeWorkflow, Invoke-ChezmoiWorkflow,
                              Show-CompletionSummary