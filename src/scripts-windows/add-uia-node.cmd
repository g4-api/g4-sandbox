@echo off
setlocal

echo WARNING: Only one UIA node is supported per machine.
echo Running multiple UIA nodes can create race conditions between automations.
echo.

set "SCRIPT_DIR=%~dp0"
set "HUB_URI=%~1"
set "NODE_PORT=%~2"

if "%HUB_URI%"=="" set "HUB_URI=http://localhost:4444/wd/hub"
if "%NODE_PORT%"=="" set "NODE_PORT=5554"

set "DOTNET=%SCRIPT_DIR%runtime\dotnet\dotnet.exe"
set "JAVA=%SCRIPT_DIR%runtime\jdk\bin\java"
set "SELENIUM_JAR=%SCRIPT_DIR%selenium-grid\selenium-server.jar"
set "UIA_DRIVER_DIR=%SCRIPT_DIR%drivers\uia-driver-server"
set "UIA_DRIVER=%UIA_DRIVER_DIR%\Uia.DriverServer.dll"
set "NODE_CONFIG=%SCRIPT_DIR%selenium-grid\configurations\uia-node.toml"

start "UIA Driver Server" /d "%UIA_DRIVER_DIR%" "%DOTNET%" "%UIA_DRIVER%" --port 5555

cd /d "%SCRIPT_DIR%selenium-grid"
"%JAVA%" -jar "%SELENIUM_JAR%" node --hub "%HUB_URI%" --config "%NODE_CONFIG%" --port "%NODE_PORT%"
