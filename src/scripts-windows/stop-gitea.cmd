@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "GITEA_STOP=%SCRIPT_DIR%gitea\stop-gitea.cmd"

if not exist "%GITEA_STOP%" (
    echo [ERROR] The portable Gitea box was not found at "%SCRIPT_DIR%gitea".
    echo [ERROR] This sandbox was published without the source-control subsystem.
    exit /b 1
)

call "%GITEA_STOP%" %*
exit /b %ERRORLEVEL%