# ============================================================================
# WSL Logging Module
# ============================================================================

<#
.SYNOPSIS
    Provides logging functionality for WSL installation scripts.

.DESCRIPTION
    This module contains functions for formatted logging with timestamps,
    color-coded severity levels, section headers, and progress logging.

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
# Logging Functions
# ============================================================================

function Write-LogMessage {
    <#
    .SYNOPSIS
        Writes formatted log messages with timestamps and enhanced colors.
    .DESCRIPTION
        Outputs log messages with consistent formatting, timestamp, and color-coded severity levels.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        The severity level: Info, Warning, Error, Success, or Debug.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Info'
    )

    if ($Level -eq 'Debug' -and -not $script:Debug) {
        return
    }

    if ($Level -eq 'Error') {
        $Message = $Message.Trim()
    }

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Color = @{
        'Info'    = 'Cyan'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
        'Success' = 'Green'
        'Debug'   = 'Magenta'
    }[$Level]
    
    # Get calling function name for debug mode
    $CallerInfo = ""
    if ($script:Debug) {
        $CallStack = Get-PSCallStack
        if ($CallStack.Count -gt 1) {
            $Caller = $CallStack[1].Command
            if ($Caller -and $Caller -ne "Write-LogMessage" -and $Caller -ne "<ScriptBlock>") {
                $CallerInfo = "[$Caller] "
            }
        }
    }
    
    Write-Host "[$Timestamp] " -ForegroundColor Gray -NoNewline
    Write-Host "[$Level] " -ForegroundColor $Color -NoNewline
    if ($CallerInfo) {
        Write-Host $CallerInfo -ForegroundColor Magenta -NoNewline
    }
    Write-Host $Message -ForegroundColor White
}

function Write-Section {
    <#
    .SYNOPSIS
        Writes a formatted section header with enhanced colors.
    .PARAMETER Title
        The section title to display.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )
    
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 70) -ForegroundColor Magenta
    Write-Host $Title -ForegroundColor Magenta -BackgroundColor Black
    Write-Host ("=" * 70) -ForegroundColor Magenta
}

function Write-ProgressLog {
    <#
    .SYNOPSIS
        Writes a progress bar with optional activity and status updates.
    .PARAMETER Activity
        The activity being performed.
    .PARAMETER Status
        The current status.
    .PARAMETER PercentComplete
        Percentage completion (0-100).
    .PARAMETER SecondsRemaining
        Estimated seconds remaining.
    .PARAMETER CurrentOperation
        Description of current operation.
    .PARAMETER Complete
        Mark the progress as complete.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,
        
        [string]$Status = "",
        [int]$PercentComplete = -1,
        [int]$SecondsRemaining = -1,
        [string]$CurrentOperation = "",
        [switch]$Complete
    )
    
    if ($Complete) {
        Write-Progress -Activity $Activity -Completed
        return
    }
    
    $ProgressParams = @{
        Activity = $Activity
    }
    
    if ($Status) { $ProgressParams.Status = $Status }
    if ($PercentComplete -ge 0) { $ProgressParams.PercentComplete = $PercentComplete }
    if ($SecondsRemaining -ge 0) { $ProgressParams.SecondsRemaining = $SecondsRemaining }
    if ($CurrentOperation) { $ProgressParams.CurrentOperation = $CurrentOperation }
    
    Write-Progress @ProgressParams
}

# Export functions
Export-ModuleMember -Function Write-LogMessage, Write-Section, Write-ProgressLog