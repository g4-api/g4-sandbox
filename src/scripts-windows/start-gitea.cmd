@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "GITEA_START=%SCRIPT_DIR%gitea\start-gitea.cmd"

if not exist "%GITEA_START%" (
    echo [ERROR] The portable Gitea box was not found at "%SCRIPT_DIR%gitea".
    echo [ERROR] This sandbox was published without the source-control subsystem.
    exit /b 1
)

call "%GITEA_START%" %*
exit /b %ERRORLEVEL%