@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "HUB_HOST=%~1"
set "HUB_PORT=%~2"

if "%HUB_PORT%"=="" set "HUB_PORT=4444"

if "%HUB_HOST%"=="" for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1).IPv4Address.IPAddress"`) do set "HUB_HOST=%%a"
if "%HUB_HOST%"=="" set "HUB_HOST=localhost"

set "JAVA=%SCRIPT_DIR%runtime\jdk\bin\java"
set "SELENIUM_JAR=%SCRIPT_DIR%selenium-grid\selenium-server.jar"

cd /d "%SCRIPT_DIR%selenium-grid"
"%JAVA%" -jar "%SELENIUM_JAR%" hub --host "%HUB_HOST%" --port "%HUB_PORT%"
