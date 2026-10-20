@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "GITEA_STOP=%SCRIPT_DIR%gitea\stop-gitea.cmd"

if not exist "%SCRIPT_DIR%gitea\" (
    echo [ERROR] The portable Gitea box was not found at "%SCRIPT_DIR%gitea".
    echo [ERROR] This sandbox was published without the source-control subsystem.
    exit /b 1
)

if not exist "%GITEA_STOP%" (
    echo [ERROR] The Gitea box at "%SCRIPT_DIR%gitea" is incomplete: "stop-gitea.cmd" is missing.
    echo [ERROR] The sandbox was published from a failed source-control deployment.
    exit /b 1
)

call "%GITEA_STOP%" %*
exit /b %ERRORLEVEL%