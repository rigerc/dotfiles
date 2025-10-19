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
    .PARAMETER Output
        The output string to clean.
    .OUTPUTS
        [string] Cleaned output string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Output
    )
    
    return ($Output -replace "`0", "").Trim()
}

# Export functions
Export-ModuleMember -Function Get-OutputRedirection, Test-WSLExitCode, Format-WSLOutput