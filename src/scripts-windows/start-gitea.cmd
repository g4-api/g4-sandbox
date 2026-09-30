@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "GITEA_START=%SCRIPT_DIR%gitea\start-gitea.cmd"

if not exist "%SCRIPT_DIR%gitea\" (
    echo [ERROR] The portable Gitea box was not found at "%SCRIPT_DIR%gitea".
    echo [ERROR] This sandbox was published without the source-control subsystem.
    exit /b 1
)

if not exist "%GITEA_START%" (
    echo [ERROR] The Gitea box at "%SCRIPT_DIR%gitea" is incomplete: "start-gitea.cmd" is missing.
    echo [ERROR] The sandbox was published from a failed source-control deployment.
    exit /b 1
)

if not exist "%SCRIPT_DIR%gitea\gitea.exe" (
    echo [ERROR] The Gitea box at "%SCRIPT_DIR%gitea" is incomplete: "gitea.exe" is missing.
    echo [ERROR] The sandbox was published from a failed source-control deployment.
    exit /b 1
)

call "%GITEA_START%" %*
exit /b %ERRORLEVEL%