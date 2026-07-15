@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "HUB_URI=%~1"
set "CHROME_NODE_PORT=%~2"
set "UIA_NODE_PORT=%~3"

if "%HUB_URI%"=="" set "HUB_URI=http://localhost:4444/wd/hub"
if "%CHROME_NODE_PORT%"=="" set "CHROME_NODE_PORT=5552"
if "%UIA_NODE_PORT%"=="" set "UIA_NODE_PORT=5554"

set "DOTNET=%SCRIPT_DIR%runtime\dotnet\dotnet.exe"
set "JAVA=%SCRIPT_DIR%runtime\jdk\bin\java"
set "SELENIUM_JAR=%SCRIPT_DIR%selenium-grid\selenium-server.jar"
set "CHROME_DRIVER_DIR=%SCRIPT_DIR%drivers\chrome"
set "CHROME_DRIVER=%CHROME_DRIVER_DIR%\chromedriver"
set "UIA_DRIVER_DIR=%SCRIPT_DIR%drivers\uia-driver-server"
set "UIA_DRIVER=%UIA_DRIVER_DIR%\Uia.DriverServer.dll"
set "CHROME_NODE_CONFIG=%SCRIPT_DIR%selenium-grid\configurations\chrome-node.toml"
set "UIA_NODE_CONFIG=%SCRIPT_DIR%selenium-grid\configurations\uia-node.toml"

start "Selenium Hub" /d "%SCRIPT_DIR%selenium-grid" "%JAVA%" -jar "%SELENIUM_JAR%" hub --session-request-timeout 42300
start "ChromeDriver" /d "%CHROME_DRIVER_DIR%" "%CHROME_DRIVER%" --port=9513
start "UIA Driver Server" /d "%UIA_DRIVER_DIR%" "%DOTNET%" "%UIA_DRIVER%" --port 5555
start "Chrome Node" /d "%SCRIPT_DIR%selenium-grid" "%JAVA%" -jar "%SELENIUM_JAR%" node --hub "%HUB_URI%" --config "%CHROME_NODE_CONFIG%" --port "%CHROME_NODE_PORT%"

cd /d "%SCRIPT_DIR%selenium-grid"
"%JAVA%" -jar "%SELENIUM_JAR%" node --hub "%HUB_URI%" --config "%UIA_NODE_CONFIG%" --port "%UIA_NODE_PORT%"
