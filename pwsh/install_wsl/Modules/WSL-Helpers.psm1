# ============================================================================
# WSL Helpers Module
# ============================================================================

<#
.SYNOPSIS
    Provides helper functions for WSL installation scripts.

.DESCRIPTION
    This module contains utility functions for output redirection,
    WSL exit code testing, and output formatting.

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
# Helper Functions
# ============================================================================

function Restart-WSLDistribution {
    <#
    .SYNOPSIS
        Restarts a WSL distribution to apply configuration changes.
    .DESCRIPTION
        Shuts down the specified WSL distribution and waits for it to become ready again.
        This is typically used after configuration changes that require a restart.
    .PARAMETER DistroName
        The name of the distribution to restart.
    .OUTPUTS
        [bool] Returns $true if the distribution became ready after restart, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    Write-Section "Restarting WSL Distribution"
    Write-LogMessage "Shutting down WSL distribution to apply changes..." -Level Info
    
    try {
        Stop-WSLDistribution -DistroName $DistroName
        Write-LogMessage "Waiting for distribution to be ready after restart..." -Level Info
        Start-Sleep -Seconds 20
        
        if (-not (Wait-ForDistributionReady -DistroName $DistroName)) {
            Write-LogMessage "Warning: Distribution failed to become ready after restart" -Level Warning
            Write-LogMessage "SSH configuration may not work properly" -Level Warning
            return $false
        }
        else {
            Write-LogMessage "Distribution is ready after restart" -Level Success
            return $true
        }
    }
    catch {
        Write-LogMessage "Failed to restart WSL distribution: $($_.Exception.Message.Trim())" -Level Warning
        Write-LogMessage "SSH configuration may not work properly" -Level Warning
        return $false
    }
}

function Get-OutputRedirection {
    <#
    .SYNOPSIS
        Returns the appropriate output redirection string based on debug mode.
    .DESCRIPTION
        When debug mode is disabled, returns a string to suppress stdout and stderr.
        When debug mode is enabled, returns an empty string to show all output.
    .OUTPUTS
        [string] Output redirection string or empty string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    if ($script:Debug) {
        return ""
    }
    return " >/dev/null 2>&1"
}

function Test-WSLExitCode {
    <#
    .SYNOPSIS
        Tests if the last WSL command succeeded.
    .DESCRIPTION
        Checks $LASTEXITCODE and throws an exception if it indicates failure.
    .PARAMETER Operation
        Description of the operation for error messages.
    .PARAMETER AllowNonZero
        If specified, non-zero exit codes are acceptable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Operation,
        
        [switch]$AllowNonZero
    )
    
    if ($LASTEXITCODE -ne 0 -and -not $AllowNonZero) {
        throw "$Operation failed with exit code: $LASTEXITCODE"
    }
}

function Format-WSLOutput {
    <#
    .SYNOPSIS
        Cleans WSL output by removing null characters and trimming whitespace.
        Handles different output modes (debug, quiet, normal) and proper error handling.
    .PARAMETER Output
        The output string to clean.
    .PARAMETER Debug
        Enable debug mode - returns raw output without cleaning.
    .PARAMETER Quiet
        Enable quiet mode - suppresses output unless there's an error.
    .OUTPUTS
        [string] Cleaned output string or empty string for quiet mode.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Output,


        [switch]$Quiet
    )
    
    # Clean the output by removing null characters and trimming whitespace
    $CleanedOutput = ($Output -replace "`0", "").Trim()

    if ($script:Debug) {
        # In debug mode, return raw output for troubleshooting
        return $Output
    }
    elseif ($Quiet) {
        # In quiet mode, check if the output contains actual errors vs warnings
        $ErrorPatterns = @(
            "error:",
            "Error:",
            "ERROR:",
            "failed",
            "Failed",
            "FAILED",
            "exception",
            "Exception",
            "EXCEPTION"
        )

        $HasRealError = $false
        foreach ($Pattern in $ErrorPatterns) {
            if ($CleanedOutput -like "*$Pattern*") {
                $HasRealError = $true
                break
            }
        }

        # If no real errors found, return empty string (quiet)
        # If real errors found, return them for visibility
        if ($HasRealError) {
            return $CleanedOutput
        }
        else {
            return ""
        }
    }
    else {
        # Normal mode - return cleaned output
        return $CleanedOutput
    }
}

# Export functions
Export-ModuleMember -Function Get-OutputRedirection, Test-WSLExitCode, Format-WSLOutput, Restart-WSLDistribution