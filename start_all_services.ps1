# ============================================
# Start All Services - Library Management System
# ============================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting All Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Kiểm tra Node.js
Write-Host "[CHECK] Node.js..." -ForegroundColor Yellow
if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVersion = node --version
    Write-Host "[OK] Node.js $nodeVersion" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Node.js not found!" -ForegroundColor Red
    exit 1
}

# Kiểm tra Python
Write-Host "[CHECK] Python..." -ForegroundColor Yellow
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonVersion = python --version
    Write-Host "[OK] $pythonVersion" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Python not found!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting Services..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Start IoT API Server (Node.js)
Write-Host "[1/2] Starting IoT API Server (port 3000)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot'; node backend/iot_api_server.js" -WindowStyle Normal
Start-Sleep -Seconds 2

# 2. Start Barcode Decoder ZXing (Python)
Write-Host "[2/2] Starting Barcode Decoder ZXing (port 5000)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot'; .venv/Scripts/Activate.ps1; python backend/barcode_decoder_zxing.py" -WindowStyle Normal
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "All Services Started!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Services running:" -ForegroundColor Cyan
Write-Host "  - IoT API Server:        http://localhost:3000" -ForegroundColor White
Write-Host "  - Barcode Decoder ZXing: http://localhost:5000" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to stop all services..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Stop all services
Write-Host ""
Write-Host "Stopping all services..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.MainWindowTitle -like "*iot_api_server*" -or $_.MainWindowTitle -like "*barcode_decoder*" -or $_.MainWindowTitle -like "*zxing*"} | Stop-Process -Force
Write-Host "Done!" -ForegroundColor Green
