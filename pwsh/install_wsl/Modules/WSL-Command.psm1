# ============================================================================
# WSL Command Execution Module
# ============================================================================

<#
.SYNOPSIS
    Provides WSL command execution functions.

.DESCRIPTION
    This module contains functions for executing commands in WSL distributions
    both programmatically and interactively.

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
# WSL Command Execution Functions
# ============================================================================

function Invoke-WSLCommand {
    <#
    .SYNOPSIS
        Executes a command in a WSL distribution.
    .DESCRIPTION
        Runs a bash command in the specified WSL distribution as a specified user.
        Provides consistent output handling and error checking.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Command
        The command to execute.
    .PARAMETER Username
        The username to run as. Defaults to 'root' if AsRoot is specified.
    .PARAMETER AsRoot
        Run the command as root user.
    .PARAMETER Quiet
        Suppress command output.
    .OUTPUTS
        [string] Command output if not in quiet mode.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,
        
        [string]$Username,
        
        [switch]$AsRoot,
        
        [switch]$Quiet
    )
    
    # Determine user
    $User = if ($AsRoot) { "root" } elseif ($Username) { $Username } else { "root" }
    
    Write-LogMessage "Executing in WSL '$DistroName' as '$User': $Command" -Level Debug
    
    $WslArgs = @("--distribution", $DistroName, "--user", $User, "--", "bash", "-c", $Command)
    
    try {
        # Execute WSL command and capture output
        $Output = & wsl @WslArgs 2>&1 | Out-String

        # Format output based on mode (debug/quiet/normal)
        return Format-WSLOutput -Output $Output -Debug:$script:Debug -Quiet:$Quiet
    }
    catch {
        Write-LogMessage "WSL command failed: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

function Invoke-WSLCommandInteractive {
    <#
    .SYNOPSIS
        Opens a new Windows Terminal window for interactive WSL commands.
    .DESCRIPTION
        Launches Windows Terminal with the specified command and waits for completion.
        Used for interactive operations like Chezmoi setup.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Command
        The command to execute.
    .PARAMETER Username
        The username to run as (defaults to root).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username
    )
    
    # Check if the distribution exists
    if (-not (Test-DistributionExists -DistroName $DistroName)) {
        throw "WSL distribution '$DistroName' does not exist or is not available"
    }
    
    $WtPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\wt.exe"
    
    if (-not (Test-Path $WtPath)) {
        throw "Windows Terminal not found at: $WtPath"
    }
    
    $StartInfo = @{
        FilePath     = "alacritty"
        ArgumentList = @("-e", "wsl -d $DistroName --user $Username --exec $Command")
        Wait         = $true
    }
    
    Write-LogMessage "Starting Windows Terminal process" -Level Info
    Start-Process -FilePath "alacritty" -ArgumentList "-e wsl -d $DistroName -u $Username -- bash -i -c '$Command;bash'" -Wait
    #Write-LogMessage "Start-Process -FilePath `"alacritty`" -ArgumentList `"-e wsl -d $DistroName -u $Username sh -c $Command`" -Wait" -Level Debug
}

# Export functions
Export-ModuleMember -Function Invoke-WSLCommand, Invoke-WSLCommandInteractive