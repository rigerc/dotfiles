# ============================================================================
# WSL Input/Configuration Module
# ============================================================================

<#
.SYNOPSIS
    Provides input gathering and configuration functions for WSL installation.

.DESCRIPTION
    This module contains functions for gathering user input, validating
    configuration, and displaying configuration summaries.

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
# Input Functions
# ============================================================================

function Get-UserInput {
    <#
    .SYNOPSIS
        Prompts user for input with a default value.
    .PARAMETER Prompt
        The prompt text to display.
    .PARAMETER Default
        The default value if user presses Enter.
    .PARAMETER UseDefault
        If true, automatically use default without prompting.
    .OUTPUTS
        [string] The user's input or default value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        
        [string]$Default,
        
        [switch]$UseDefault
    )
    
    if ($UseDefault -and $Default) {
        Write-LogMessage "Using default value for '$Prompt': $Default" -Level Info
        return $Default
    }
    
    $DisplayDefault = if ($Default) { " [$Default]" } else { "" }
    Write-Host $Prompt -ForegroundColor Blue -NoNewline
    Write-Host $DisplayDefault -ForegroundColor Yellow -NoNewline
    Write-Host ": " -ForegroundColor White -NoNewline
    $UserInput = Read-Host
    
    if ($UserInput) {
        return $UserInput
    }
    
    return $Default
}

function Get-ValidatedUsername {
    <#
    .SYNOPSIS
        Prompts for and validates a Linux username.
    .PARAMETER Default
        The default username value.
    .PARAMETER UseDefault
        If true, automatically use default if valid.
    .OUTPUTS
        [string] A valid Linux username.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Default,
        
        [switch]$UseDefault
    )
    
    if ($UseDefault -and $Default) {
        if (Test-ValidLinuxUsername -Username $Default) {
            Write-LogMessage "Using default username: $Default" -Level Info
            return $Default
        }
        else {
            Write-LogMessage "Default username '$Default' is invalid. Using 'user' instead." -Level Warning
            return 'user'
        }
    }
    
    do {
        $Username = Get-UserInput -Prompt "Username for new user" -Default $Default
        
        if (Test-ValidLinuxUsername -Username $Username) {
            return $Username
        }
        
        Write-LogMessage "Invalid username. Must start with lowercase letter/underscore, contain only lowercase letters, numbers, underscore, hyphen (max 32 chars)" -Level Error
        $Default = $null
    } while ($true)
}

function Get-ConfigurationInput {
    <#
    .SYNOPSIS
        Gathers all configuration inputs from the user or uses defaults.
    .DESCRIPTION
        Collects distribution name, image, username, and optional settings
        like Chezmoi and git configuration.
    .PARAMETER ContinueMode
        Whether running in Continue mode (skips image prompt).
    .PARAMETER UseDefaults
        Whether to use default values without prompting.
    .PARAMETER WithChezmoi
        Whether Chezmoi is explicitly requested.
    .OUTPUTS
        [hashtable] Configuration object with all settings.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [switch]$ContinueMode,
        [switch]$UseDefaults,
        [switch]$WithChezmoi
    )
    
    begin {}
    
    process {
        $Config = @{
            DistroImage = $null
            DistroName = $null
            Username = $null
            UseChezmoi = $false
            GitName = $null
            GitEmail = $null
        }
        
        # Gather basic inputs
        if (-not $UseDefaults) {
            Write-Host "`nPlease provide the following information (press Enter for defaults):`n"
        }
        else {
            Write-LogMessage "Running with default values (use -WithDefaults:`$false to customize)" -Level Info
        }
        
        if ($ContinueMode) {
            $Config.DistroName = Get-UserInput -Prompt "Distribution name to work with" -Default $script:DefaultName -UseDefault:$UseDefaults
            $Config.Username = Get-ValidatedUsername -Default $script:DefaultUsername -UseDefault:$UseDefaults
        }
        else {
            $Config.DistroImage = Get-UserInput -Prompt "Distribution image" -Default $script:DefaultDistro -UseDefault:$UseDefaults
            $Config.DistroName = Get-UserInput -Prompt "Distribution name to create" -Default $script:DefaultName -UseDefault:$UseDefaults
            $Config.Username = Get-ValidatedUsername -Default $script:DefaultUsername -UseDefault:$UseDefaults
        }
        
        # Determine Chezmoi usage
        if ($WithChezmoi) {
            $Config.UseChezmoi = $true
        }
        elseif (-not $UseDefaults) {
            $ChezmoiPrompt = Read-Host "Use Chezmoi for dotfiles management? (y/N)"
            $Config.UseChezmoi = $ChezmoiPrompt -eq 'y' -or $ChezmoiPrompt -eq 'Y'
        }
        else {
            Write-LogMessage "Chezmoi: Disabled (use -WithChezmoi to enable)" -Level Info
        }
        
        # Get Git configuration if Chezmoi is requested
        if ($Config.UseChezmoi) {
            if (-not (Test-GitAvailable)) {
                Write-LogMessage "Git is not installed or not in PATH. Chezmoi setup will be skipped." -Level Warning
                $Config.UseChezmoi = $false
            }
            else {
                if (-not $UseDefaults) {
                    Write-Host "`nGit configuration (for Chezmoi):`n"
                }
                
                $DefaultGitName = Get-GitConfig -ConfigKey "user.name"
                $Config.GitName = Get-UserInput -Prompt "Github username" -Default $DefaultGitName -UseDefault:$UseDefaults
                
                $DefaultGitEmail = Get-GitConfig -ConfigKey "user.email"
                $Config.GitEmail = Get-UserInput -Prompt "Github email" -Default $DefaultGitEmail -UseDefault:$UseDefaults
                
                if (-not $Config.GitName -or -not $Config.GitEmail) {
                    Write-LogMessage "Git configuration incomplete. Chezmoi setup will be skipped." -Level Warning
                    $Config.UseChezmoi = $false
                }
            }
        }
        
        return $Config
    }
}

function Show-ConfigurationSummary {
    <#
    .SYNOPSIS
        Displays a summary of the configuration.
    .PARAMETER Config
        The configuration hashtable to display.
    .PARAMETER ContinueMode
        Whether running in Continue mode.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [switch]$ContinueMode
    )
    
    Write-Section "Configuration Summary"
    
    if (-not $ContinueMode -and $Config.DistroImage) {
        Write-Host "Distribution Image: " -ForegroundColor White -NoNewline
        Write-Host $Config.DistroImage -ForegroundColor Cyan
    }
    
    Write-Host "Distribution Name:  " -ForegroundColor White -NoNewline
    Write-Host $Config.DistroName -ForegroundColor Cyan
    
    Write-Host "Username:           " -ForegroundColor White -NoNewline
    Write-Host $Config.Username -ForegroundColor Cyan
    
    if ($Config.UseChezmoi) {
        Write-Host "Chezmoi:            " -ForegroundColor White -NoNewline
        Write-Host "Enabled" -ForegroundColor Green
        Write-Host "Git Name:           " -ForegroundColor White -NoNewline
        Write-Host $Config.GitName -ForegroundColor Cyan
        Write-Host "Git Email:          " -ForegroundColor White -NoNewline
        Write-Host $Config.GitEmail -ForegroundColor Cyan
    }
    else {
        Write-Host "Chezmoi:            " -ForegroundColor White -NoNewline
        Write-Host "Disabled" -ForegroundColor Red
    }
    
    if ($ContinueMode) {
        Write-Host "Mode:               " -ForegroundColor White -NoNewline
        Write-Host "Continue" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Export functions
Export-ModuleMember -Function Get-UserInput, Get-ValidatedUsername, 
                              Get-ConfigurationInput, Show-ConfigurationSummary