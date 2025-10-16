# PowerShell script to reinstall WSL distribution and configure it with working SSH (unattended)
# Prompts for distribution, name, username and password at the start

$ErrorActionPreference = "Stop"

try {
    # --- DISTRIBUTION AND NAME INPUT ---
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "WSL Distribution Setup" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Enter distribution to install (default: archlinux):" -ForegroundColor Yellow
    Write-Host "  Common options: archlinux, Ubuntu, Debian, kali-linux" -ForegroundColor Gray
    $distro = Read-Host
    if ([string]::IsNullOrWhiteSpace($distro)) {
        $distro = "archlinux"
        Write-Host "Using default: archlinux" -ForegroundColor Green
    }

    Write-Host "`nEnter name for the distribution (default: newarchlinux):" -ForegroundColor Yellow
    $distroName = Read-Host
    if ([string]::IsNullOrWhiteSpace($distroName)) {
        $distroName = "newarchlinux"
        Write-Host "Using default: newarchlinux" -ForegroundColor Green
    }

    if ($distroName -notmatch '^[a-zA-Z0-9_-]+$') {
        throw "Invalid distribution name. Use letters, numbers, underscores, and hyphens only."
    }

    # --- USER INPUT ---
    Write-Host "`nEnter username to create:" -ForegroundColor Yellow
    do {
        $username = Read-Host
        if ([string]::IsNullOrWhiteSpace($username)) {
            Write-Host "Username cannot be empty. Please try again." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($username))

    if ($username -notmatch '^[a-z_][a-z0-9_-]*$') {
        throw "Invalid username format. Use lowercase letters, numbers, underscores, and hyphens only. Must start with a letter or underscore."
    }

    $password = Read-Host "Enter password for $username" -AsSecureString
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Configuration Summary:" -ForegroundColor Cyan
    Write-Host "  Distribution: $distro" -ForegroundColor White
    Write-Host "  Name: $distroName" -ForegroundColor White
    Write-Host "  Username: $username" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Cyan

    # --- REMOVE EXISTING DISTRO ---
    Write-Host "Unregistering existing '$distroName' distribution..." -ForegroundColor Yellow
    $unregisterResult = wsl --unregister $distroName 2>&1
    if ($LASTEXITCODE -ne 0 -and $unregisterResult -notmatch "not found|does not exist") {
        throw "Failed to unregister distribution: $unregisterResult"
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully unregistered existing distribution" -ForegroundColor Green
    } else {
        Write-Host "No existing distribution found (continuing)" -ForegroundColor Yellow
    }

    # --- INSTALL NEW DISTRO ---
    Write-Host "Installing $distro distribution as '$distroName'..." -ForegroundColor Yellow
    wsl --install $distro --name $distroName --no-launch
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install $distro distribution. Exit code: $LASTEXITCODE"
    }

    Write-Host "Distribution installed successfully" -ForegroundColor Green

    # --- PHASE 1 SETUP ---
    Write-Host "Configuring $distro (Phase 1: Initial setup)..." -ForegroundColor Green
    $tempScript = [System.IO.Path]::GetTempFileName()
$bashScriptContent = @"
set -e

echo "Initializing pacman keyring..."
pacman-key --init >/dev/null 2>&1 || exit 1
pacman-key --populate archlinux >/dev/null 2>&1 || exit 1

echo "Updating system and installing packages..."
pacman -Syu --noconfirm --needed --quiet git openssh sudo curl chezmoi grep gawk jq deno >/dev/null || exit 1

echo "Creating user $username..."
useradd -m -G wheel -s /bin/bash $username || exit 1
echo "${username}:${plainPassword}" | chpasswd || exit 1

echo "Configuring sudo..."
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

echo "Enabling systemd in WSL..."
cat > /etc/wsl.conf << 'EOF'
[boot]
systemd=true

[user]
default=$username
EOF

echo "Configuring SSH on port 4444..."
sed -i 's/^#*Port .*/Port 4444/' /etc/ssh/sshd_config
sed -i 's/^#*ListenAddress .*/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

echo "Generating SSH host keys..."
ssh-keygen -A || exit 1

echo "Phase 1 configuration complete!"
"@

    Set-Content -Path $tempScript -Value $bashScriptContent -Encoding UTF8

    $wslTempPath = "/tmp/wsl-setup-$(Get-Random).sh"
    Get-Content $tempScript -Raw | wsl -d $distroName bash -c "tr -d '\r' > $wslTempPath"
    wsl -d $distroName bash $wslTempPath
    $exitCode = $LASTEXITCODE

    wsl -d $distroName rm -f $wslTempPath
    Remove-Item -Path $tempScript -Force

    if ($exitCode -ne 0) {
        throw "Failed to configure $distro distribution (Phase 1). Exit code: $exitCode"
    }

    Write-Host "Phase 1 completed successfully!" -ForegroundColor Green

    # --- PHASE 2: ENABLE SSH ---
    Write-Host "`nTerminating distribution to enable systemd..." -ForegroundColor Yellow
    wsl --terminate $distroName
    Start-Sleep -Seconds 2

    Write-Host "Configuring SSH service (Phase 2: Starting SSH)..." -ForegroundColor Green
    $tempScript2 = [System.IO.Path]::GetTempFileName()
$bashScriptContent2 = @'
set -e

echo "Waiting for systemd to initialize..."
sleep 2

echo "Enabling and starting SSH service..."
sudo systemctl enable sshd || exit 1
sudo systemctl start sshd || exit 1

if systemctl is-active --quiet sshd; then
    echo "SSH service is running successfully!"
else
    echo "ERROR: SSH service failed to start"
    systemctl status sshd
    exit 1
fi
'@

    Set-Content -Path $tempScript2 -Value $bashScriptContent2 -Encoding UTF8
    $wslTempPath2 = "/tmp/wsl-setup2-$(Get-Random).sh"
    Get-Content $tempScript2 -Raw | wsl -d $distroName bash -c "tr -d '\r' > $wslTempPath2"
    wsl -d $distroName bash $wslTempPath2
    $exitCode2 = $LASTEXITCODE
    wsl -d $distroName rm -f $wslTempPath2
    Remove-Item -Path $tempScript2 -Force

    if ($exitCode2 -ne 0) {
        throw "Failed to start SSH service (Phase 2). Exit code: $exitCode2"
    }

    Write-Host "SSH service started successfully!" -ForegroundColor Green

    # --- PORT FORWARDING ---
    Write-Host "`nConfiguring Windows port forwarding..." -ForegroundColor Yellow
    
    # Try multiple methods to get WSL IP
    $wslIp = $null
    
    # Method 1: ip addr show eth0
    $output = wsl.exe -d $distroName ip addr show eth0 2>$null
    if ($output -match 'inet\s+(\d+\.\d+\.\d+\.\d+)/') {
        $wslIp = $matches[1]
    }
    
    # Method 2: Check all interfaces excluding loopback
    if (-not $wslIp) {
        $output = wsl.exe -d $distroName ip -4 addr show 2>$null | Select-String -Pattern 'inet\s+(\d+\.\d+\.\d+\.\d+)/' -AllMatches
        foreach ($match in $output.Matches) {
            $ip = $match.Groups[1].Value
            if ($ip -notmatch '^127\.') {
                $wslIp = $ip
                break
            }
        }
    }
    
    # Method 3: Use grep to find non-loopback IP
    if (-not $wslIp) {
        $output = wsl.exe -d $distroName bash -c "ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.'" 2>$null
        if ($output -match '(\d+\.\d+\.\d+\.\d+)') {
            $wslIp = $matches[1]
        }
    }
    
    if ($wslIp) {
        Write-Host "WSL IP address: $wslIp" -ForegroundColor Cyan

        netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=4444 2>$null
        netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=4444 connectaddress=$wslIp connectport=4444
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Port forwarding configured successfully" -ForegroundColor Green
        }

        Remove-NetFirewallRule -DisplayName "Allow SSH on port 4444" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "Allow SSH on port 4444" -Direction Inbound -Protocol TCP -Action Allow -LocalPort 4444 | Out-Null
        Write-Host "Firewall rule created successfully" -ForegroundColor Green
    } else {
        Write-Host "Warning: Could not determine WSL IP address." -ForegroundColor Yellow
        Write-Host "You may need to configure port forwarding manually." -ForegroundColor Yellow
    }

    # --- SUMMARY ---
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Setup Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Distribution: $distro ($distroName)" -ForegroundColor Cyan
    Write-Host "Default user: $username" -ForegroundColor Cyan
    Write-Host "SSH port: 4444" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Green

    # --- INTERACTIVE PROMPT FOR CHEZMOI ---
    $startChezmoi = Read-Host "Do you want to run chezmoi bootstrap now? (y/N)"
    if ($startChezmoi -match '^(y|Y)$') {
        Write-Host "Running chezmoi bootstrap..." -ForegroundColor Yellow
        wsl -d $distroName -u $username bash -c 'curl -fsSL get.chezmoi.io | sh -s -- init --apply rigerc'
        Write-Host "Chezmoi bootstrap finished!" -ForegroundColor Green
    } else {
        Write-Host "Skipped bootstrap..." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "ERROR: Script execution failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}