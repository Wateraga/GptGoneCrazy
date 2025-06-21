# GptGoneCrazy

This repository contains a Windows 11 setup script focused on privacy and security. The script configures several built-in options to reduce data collection and harden the system.

## Usage
1. Open **PowerShell** with administrative privileges.
2. Allow the script to run temporarily:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```
3. Execute the script:

```powershell
./setup_windows11_privacy_security.ps1
```

After running, reboot Windows to ensure all changes take effect.

## Features
- Disables telemetry and advertising ID
- Disables location services and error reporting
- Enables the firewall for all profiles
- Turns on Windows Defender Potentially Unwanted Application protection

Feel free to review and adapt the script to your specific needs.

