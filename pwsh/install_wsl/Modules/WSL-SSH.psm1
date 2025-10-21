# ============================================================================
# WSL SSH Module
# ============================================================================

<#
.SYNOPSIS
    Provides SSH configuration functions for WSL distributions.

.DESCRIPTION
    This module contains functions for configuring SSH port forwarding,
    managing firewall rules, and testing SSH services.

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
# SSH Functions
# ============================================================================

function Test-SSHDRunning {
    <#
    .SYNOPSIS
        Checks if sshd is running in the WSL distribution.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .OUTPUTS
        [bool] True if sshd is running, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    try {
        $Command = "systemctl is-active sshd 2>/dev/null || service ssh status 2>/dev/null"
        $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot
        return $Result -match "active|running"
    }
    catch {
        return $false
    }
}

function Get-SSHDPort {
    <#
    .SYNOPSIS
        Retrieves the SSH port from sshd configuration.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .OUTPUTS
        [int] The SSH port number (defaults to 22).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    try {
        # Try multiple methods to get the SSH port
        $Commands = @(
            # Method 1: Use sed to extract Port line and get the number
            "sed -n 's/^Port\s\+\([0-9]\+\).*/\1/p' /etc/ssh/sshd_config 2>/dev/null | head -n1",
            # Method 2: Use grep and awk (fixed escaping)
            "grep '^Port\>' /etc/ssh/sshd_config 2>/dev/null | awk '{print \$2}' | head -n1",
            # Method 3: Use awk directly
            "awk '/^Port\>/ {print \$2; exit}' /etc/ssh/sshd_config 2>/dev/null"
        )

        foreach ($Cmd in $Commands) {
            try {
                $Result = Invoke-WSLCommand -DistroName $DistroName -Command $Cmd -AsRoot

                if ($null -ne $Result -and $Result.Trim() -ne '') {
                    $PortString = $Result.Trim()

                    # Remove any additional whitespace or newlines
                    $PortString = ($PortString -split '[\r\n\s]+' | Select-Object -First 1).Trim()

                    if ($PortString -match '^\d+$') {
                        $Port = [int]$PortString
                        Write-LogMessage "Successfully retrieved SSH port: $Port" -Level Debug
                        return $Port
                    }
                }
            }
            catch {
                Write-LogMessage "SSH port detection method failed: $($_.Exception.Message.Trim())" -Level Debug
                continue
            }
        }

        # If all methods fail, try to get default port by checking if sshd is running on default port
        Write-LogMessage "Could not extract SSH port from config, checking if default port 22 is in use" -Level Debug
        $DefaultPortCheck = "ss -tlnp 2>/dev/null | grep ':22\s'"
        $DefaultPortResult = Invoke-WSLCommand -DistroName $DistroName -Command $DefaultPortCheck -AsRoot

        if ($null -ne $DefaultPortResult -and $DefaultPortResult.Trim() -ne '') {
            Write-LogMessage "SSH daemon appears to be running on default port 22" -Level Debug
            return 22
        }

        # Default SSH port if nothing else works
        Write-LogMessage "Using default SSH port 22 (could not determine from config)" -Level Warning
        return 22
    }
    catch {
        Write-LogMessage "Error retrieving SSH port: $($_.Exception.Message.Trim())" -Level Warning
        return 22
    }
}

function Get-WSLIPAddress {
    <#
    .SYNOPSIS
        Retrieves the IP address of a WSL distribution.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .OUTPUTS
        [string] The IP address of the distribution.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    # Try multiple methods to get the WSL IP address
    $Methods = @(
        # Method 1: hostname -I (may not be available in all distributions)
        "hostname -I 2>/dev/null | awk '{print `$1}'",
        # Method 2: ip command to get eth0 address
        "ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1",
        # Method 3: ip command with full path
        "/sbin/ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1",
        # Method 4: Try all interfaces
        "ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1"
    )
    
    foreach ($Method in $Methods) {
        try {
            $WslIpOutput = Invoke-WSLCommand -DistroName $DistroName -Command $Method -AsRoot
            $WslIp = $WslIpOutput.Trim()
            
            # Validate IP address format
            if ($WslIp -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                Write-LogMessage "Found WSL IP address using method: $Method" -Level Debug
                Write-LogMessage "IP Address: $WslIp" -Level Debug
                return $WslIp
            }
        }
        catch {
            Write-LogMessage "IP detection method failed: $Method" -Level Debug
            continue
        }
    }
    
    throw "Could not retrieve WSL IP address using any available method. Make sure the distribution is running and has network connectivity."
}

function New-SSHPortForward {
    <#
    .SYNOPSIS
        Creates SSH port forwarding from Windows host to WSL distribution.
    .DESCRIPTION
        Sets up port forwarding by getting the WSL IP address and creating a netsh
        port proxy rule to forward traffic from a Windows host port to the WSL SSH port.
    .PARAMETER Port
        The external port on Windows host to forward from.
    .PARAMETER DistroName
        The name of the WSL distribution to forward to.
    .PARAMETER ListenAddress
        The IP address to listen on (default: 0.0.0.0).
    .PARAMETER ConnectPort
        The SSH port inside WSL (default: same as Port).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [string]$ListenAddress = "0.0.0.0",
        
        [int]$ConnectPort = $Port
    )
    
    Write-LogMessage "Getting WSL IP address for distribution: $DistroName" -Level Info
    
    try {
        $WslIp = Get-WSLIPAddress -DistroName $DistroName
        Write-LogMessage "WSL IP address: $WslIp" -Level Info
        
        # Remove existing port proxy rule (if any)
        Write-LogMessage "Removing existing port proxy rule for port $Port..." -Level Info
        $null = netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=$ListenAddress 2>$null
        
        # Add new port proxy rule
        Write-LogMessage "Adding new port proxy rule..." -Level Info
        $AddResult = netsh interface portproxy add v4tov4 listenaddress=$ListenAddress listenport=$Port connectaddress=$WslIp connectport=$ConnectPort
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "SSH port forwarding created successfully" -Level Success
            Write-LogMessage "Windows host port $Port now forwards to ${DistroName}:$ConnectPort" -Level Info
        }
        else {
            throw "Failed to create port forwarding rule. Error: $AddResult"
        }
    }
    catch {
        Write-LogMessage "Failed to create SSH port forwarding: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

function New-SSHFirewallRule {
    <#
    .SYNOPSIS
        Creates a Windows Firewall rule for SSH port forwarding.
    .PARAMETER Port
        The port to create firewall rule for.
    .PARAMETER DistroName
        The name of the WSL distribution (used in rule name).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
    
    $RuleName = "WSL-$DistroName-SSH-$Port"
    
    try {
        # Check if rule already exists
        $ExistingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
        
        if ($ExistingRule) {
            Write-LogMessage "Firewall rule '$RuleName' already exists" -Level Info
            return
        }
        
        # Create new firewall rule
        $null = New-NetFirewallRule -DisplayName $RuleName `
            -Direction Inbound `
            -Action Allow `
            -Protocol TCP `
            -LocalPort $Port `
            -Profile Any `
            -Description "SSH access for WSL distribution: $DistroName"
        
        Write-LogMessage "Created firewall rule '$RuleName' for port $Port" -Level Success
    }
    catch {
        Write-LogMessage "Failed to create firewall rule: $($_.Exception.Message.Trim())" -Level Error
        throw
    }
}

function Invoke-SSHConfiguration {
    <#
    .SYNOPSIS
        Configures SSH port forwarding and firewall rules.
    .PARAMETER DistroName
        The name of the WSL distribution.
    .PARAMETER UseDefaults
        Whether to skip prompts and use defaults.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,
        
        [switch]$UseDefaults
    )
    
    Write-Section "SSH Port Forwarding Configuration"
    
    $ConfigureSSH = $false

    $Response = Read-Host "Configure SSH Port Forwarding? (Y/n)"
    $ConfigureSSH = -not ($Response -eq 'n' -or $Response -eq 'N')
    
    if (-not $ConfigureSSH) {
        return
    }
    
    Start-Sleep 5
    # Verify sshd is running
    if (-not (Test-SSHDRunning -DistroName $DistroName)) {
        Write-LogMessage "sshd is not running in WSL distribution" -Level Warning
        $StartSSHD = Read-Host "Would you like to start sshd? (Y/n)"
        
        if (-not ($StartSSHD -eq 'n' -or $StartSSHD -eq 'N')) {
            try {
                $Command = "systemctl start sshd || service ssh start"
                Invoke-WSLCommand -DistroName $DistroName -Command $Command -AsRoot -Quiet
                Start-Sleep -Seconds 2
                
                if (-not (Test-SSHDRunning -DistroName $DistroName)) {
                    Write-LogMessage "Failed to start sshd - configuration skipped" -Level Warning
                    return
                }
            }
            catch {
                Write-LogMessage "Failed to start sshd: $($_.Exception.Message.Trim())" -Level Error
                return
            }
        }
        else {
            Write-LogMessage "SSH configuration skipped - sshd not running" -Level Warning
            return
        }
    }
    
    # Get SSH port and configure forwarding
    try {
        $SshPort = Get-SSHDPort -DistroName $DistroName
        Write-LogMessage "Detected SSH port: $SshPort" -Level Info
        
        New-SSHPortForward -Port $SshPort -DistroName $DistroName
        New-SSHFirewallRule -Port $SshPort -DistroName $DistroName
    }
    catch {
        Write-LogMessage "SSH configuration failed: $($_.Exception.Message.Trim())" -Level Warning
    }
}

# Export functions
Export-ModuleMember -Function Test-SSHDRunning, Get-SSHDPort, Get-WSLIPAddress, 
                              New-SSHPortForward, New-SSHFirewallRule, Invoke-SSHConfiguration