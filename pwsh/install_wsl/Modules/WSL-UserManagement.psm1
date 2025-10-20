# ============================================================================
# WSL User Management Module
# ============================================================================

<#
.SYNOPSIS
    Provides user management functions for WSL distributions.

.DESCRIPTION
    This module contains functions for creating users, configuring sudo access,
    and testing user configurations.

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
# User Management Functions
# ============================================================================

function New-WSLUser {
    <#
    .SYNOPSIS
        Creates a new user in the WSL distribution.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Username
        The username to create.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username
    )
    
    Write-Section "Creating WSL User"
    
    try {
        # Create user
        Write-LogMessage "Creating user: $Username" -Level Info
        $Command = "useradd -m -s /bin/bash $Username"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        
        # Verify user creation
        $Command = "id $Username"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        
        Write-LogMessage "User created successfully: $Username" -Level Success
    }
    catch {
        Write-LogMessage "Failed to create user: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

function Add-UserToSudoers {
    <#
    .SYNOPSIS
        Adds user to sudoers with passwordless sudo.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Username
        The username to configure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username
    )
    
    Write-Section "Configuring Sudo Access"
    
    try {
        # Add user to wheel group
        Write-LogMessage "Adding user to wheel group..." -Level Info
        $Command = "usermod -aG wheel $Username"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        
        # Configure passwordless sudo for wheel group
        Write-LogMessage "Configuring passwordless sudo..." -Level Info
        $Command = "echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers.d/wheel && chmod 440 /etc/sudoers.d/wheel"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        

        # Configure systemd
        Write-LogMessage "Configuring systemd" -Level Info
        $systemD= "[boot]`nsystemd=true`n`n[user]`ndefault=$username`n`n"
        $Command = "echo '$systemD' | sudo tee /etc/wsl.conf > /dev/null"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet

        # Verify sudo access
        Write-LogMessage "Verifying sudo access..." -Level Info
        Start-Sleep -Seconds 2
        
        if (Test-UserSudoAccess -DistroName $DistroName -Username $Username) {
            Write-LogMessage "Sudo access configured and verified successfully" -Level Success
        }
        else {
            Write-LogMessage "Sudo access configured but verification failed" -Level Warning
            Write-LogMessage "You may need to restart the WSL distribution" -Level Warning
        }
    }
    catch {
        Write-LogMessage "Failed to configure sudo access: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

function Test-Configuration {
    <#
    .SYNOPSIS
        Tests the WSL configuration to ensure it is correct.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER Username
        The username to test.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username
    )
    
    Write-Section "Testing Configuration"
    
    try {
        # Test user ID
        Write-LogMessage "Testing user information..." -Level Info
        $Command = "id $Username"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        
        # Test user groups
        Write-LogMessage "Testing user groups..." -Level Info
        $Command = "groups $Username"
        Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
        
        # Test sudo access
        if (-not (Test-UserSudoAccess -DistroName $DistroName -Username $Username)) {
            Write-LogMessage "Warning: Sudo configuration may not be working properly" -Level Warning
        }
        else {
            Write-LogMessage "Sudo access verified" -Level Success
        }
        
        Write-LogMessage "Configuration testing complete" -Level Success
    }
    catch {
        Write-LogMessage "Configuration testing failed: $($_.Exception.Message.Trim())" -Level Warning
    }
}

# Export functions
Export-ModuleMember -Function New-WSLUser, Add-UserToSudoers, Test-Configuration