# Setup Windows Firewall Rule for IoT API Server
# Run as Administrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup Firewall for IoT API Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

# Remove old rule if exists
Write-Host "Removing old firewall rule (if exists)..." -ForegroundColor Yellow
Remove-NetFirewallRule -DisplayName "IoT API Server - Port 3000" -ErrorAction SilentlyContinue

# Add new rule for Inbound TCP 3000
Write-Host "Adding firewall rule for TCP port 3000..." -ForegroundColor Green
New-NetFirewallRule -DisplayName "IoT API Server - Port 3000" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 3000 `
    -Action Allow `
    -Profile Any `
    -Enabled True `
    -Description "Allow ESP32 devices to connect to IoT API Server on port 3000"

Write-Host ""
Write-Host "SUCCESS! Firewall rule added." -ForegroundColor Green
Write-Host ""
Write-Host "You can now access the API from ESP32 devices at:" -ForegroundColor Cyan
Write-Host "  http://YOUR_IP:3000" -ForegroundColor White
Write-Host ""
Write-Host "To check your IP address, run:" -ForegroundColor Yellow
Write-Host "  ipconfig" -ForegroundColor White
Write-Host ""

pause
