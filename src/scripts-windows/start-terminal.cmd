@echo off
setlocal

set "WT_EXE=%~dp0bot-utilities\windows-terminal\wt.exe"

if not exist "%WT_EXE%" (
    echo Bundled Windows Terminal was not found: "%WT_EXE%"
    exit /b 1
)

start "" "%WT_EXE%" -w new -d "%~dp0."

endlocal
