@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "HUB_URI=%~1"
set "NODE_PORT=%~2"

if "%HUB_URI%"=="" set "HUB_URI=http://localhost:4444/wd/hub"
if "%NODE_PORT%"=="" set "NODE_PORT=5552"

set "JAVA=%SCRIPT_DIR%runtime\jdk\bin\java"
set "SELENIUM_JAR=%SCRIPT_DIR%selenium-grid\selenium-server.jar"
set "CHROME_DRIVER=%SCRIPT_DIR%drivers\chrome\chromedriver"
set "NODE_CONFIG=%SCRIPT_DIR%selenium-grid\configurations\chrome-node.toml"

start "Selenium Hub" /d "%SCRIPT_DIR%selenium-grid" "%JAVA%" -jar "%SELENIUM_JAR%" hub --session-request-timeout 42300
start "ChromeDriver" /d "%SCRIPT_DIR%drivers\chrome" "%CHROME_DRIVER%" --port=9513

cd /d "%SCRIPT_DIR%selenium-grid"
"%JAVA%" -jar "%SELENIUM_JAR%" node --hub "%HUB_URI%" --config "%NODE_CONFIG%" --port "%NODE_PORT%"
