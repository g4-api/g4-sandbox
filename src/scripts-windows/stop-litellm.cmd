@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "LITELLM_STOP=%SCRIPT_DIR%litellm\stop-litellm.cmd"

if not exist "%LITELLM_STOP%" (
    echo [ERROR] The portable LiteLLM box was not found at "%SCRIPT_DIR%litellm".
    echo [ERROR] This sandbox was published without the LiteLLM subsystem.
    exit /b 1
)

call "%LITELLM_STOP%" %*
exit /b %ERRORLEVEL%
