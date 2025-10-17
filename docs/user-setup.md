# User Setup with Chezmoi

## Overview

The `run_once_01-create-user.sh.tmpl` script automates the process of creating a new user with sudo privileges on a Linux system. This script is designed to run only once during initial system setup.

## What It Does

1. **Creates a new user** with the username specified during Chezmoi initialization
2. **Adds the user to the wheel group** for administrative privileges
3. **Configures sudoers** to allow wheel group members to use sudo without password
4. **Validates sudoers syntax** to prevent configuration errors

## Prerequisites

- Must be run as root (use sudo)
- User must not already exist
- System must support useradd/groupadd commands

## Usage

### During Initial Setup

1. **Initialize Chezmoi** (this will prompt for username):
   ```bash
   chezmoi init --apply https://github.com/yourusername/dotfiles.git
   ```

2. **The script will automatically run** during the first `chezmoi apply` and create the user

### Manual Execution

If you need to run the script manually:

```bash
# As root, execute the generated script
sudo /home/user/.local/share/chezmoi/run_once_01-create-user.sh
```

## Script Details

### Variables Used

- `{{ .data.username }}`: The username provided during Chezmoi initialization

### File Locations

- **Source**: `run_once_01-create-user.sh.tmpl`
- **Generated**: `~/.local/share/chezmoi/run_once_01-create-user.sh`
- **Sudoers config**: `/etc/sudoers.d/wheel`

### Security Features

- **Syntax validation**: Uses `visudo -c` to validate sudoers configuration
- **Proper permissions**: Sets sudoers file to 440 (read-only for owner/group)
- **Error handling**: Exits on any error with clear messages
- **Idempotent**: Safe to run multiple times (checks for existing users/groups)

## After Script Runs

1. **New user created** with home directory `/home/username`
2. **User added to wheel group** for sudo access
3. **Passwordless sudo enabled** for wheel group members
4. **Login as new user**:
   ```bash
   su - username
   ```

## Customization

### Set Initial Password

Uncomment the password section in the script to set a temporary password:

```bash
# Uncomment in the script:
TEMP_PASSWORD="tempPassword123"
echo "$NEW_USER:$TEMP_PASSWORD" | chpasswd
```

### Modify Sudoers Configuration

Change the sudoers line in the script if you prefer password prompts:

```bash
# Instead of NOPASSWD:
%wheel ALL=(ALL:ALL) ALL
```

## Troubleshooting

### Script Fails with "User already exists"

- The script detects existing users and skips creation
- This is normal behavior if the user was previously created

### Sudoers Validation Fails

- The script automatically removes invalid sudoers files
- Check the syntax and ensure no existing conflicts in `/etc/sudoers.d/`

### Permission Denied

- Ensure script is run with root privileges
- Check that the source template has execute permissions

## Security Considerations

⚠️ **Important**: Passwordless sudo provides full administrative access without authentication. Consider these security implications:

1. **Use only for trusted users**
2. **Consider using password-protected sudo** in production environments
3. **Regular user accounts** should not be in the wheel group
4. **Monitor sudo usage** through system logs

### Alternative Secure Configuration

For enhanced security, modify the sudoers line to require passwords:

```bash
%wheel ALL=(ALL:ALL) ALL
```

This requires wheel group members to enter their password for sudo operations.