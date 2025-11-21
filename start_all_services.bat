@echo off
REM ============================================
REM Start All Services - Library Management System
REM ============================================

echo ========================================
echo Starting All Services
echo ========================================
echo.

REM Check Node.js
echo [CHECK] Node.js...
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Node.js not found!
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('node --version') do set NODE_VERSION=%%i
echo [OK] Node.js %NODE_VERSION%

REM Check Python
echo [CHECK] Python...
where python >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Python not found!
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('python --version') do set PYTHON_VERSION=%%i
echo [OK] %PYTHON_VERSION%

echo.
echo ========================================
echo Starting Services...
echo ========================================
echo.

REM 1. Start IoT API Server
echo [1/2] Starting IoT API Server (port 3000)...
start "IoT API Server" cmd /k "node backend\iot_api_server.js"
timeout /t 2 /nobreak >nul

REM 2. Start Barcode Decoder (ZXing version)
echo [2/2] Starting Barcode Decoder ZXing (port 5000)...
start "Barcode Decoder ZXing" cmd /k ".venv\Scripts\activate.bat && python backend\barcode_decoder_zxing.py"
timeout /t 2 /nobreak >nul

echo.
echo ========================================
echo All Services Started!
echo ========================================
echo.
echo Services running:
echo   - IoT API Server:        http://localhost:3000
echo   - Barcode Decoder ZXing: http://localhost:5000
echo.
echo Press any key to exit (services will keep running)...
pause >nul
