@echo off
start "G4 Hub" /d "%~dp0g4-hub" "%~dp0runtime\dotnet\dotnet.exe" G4.Services.Hub.dll
start "G4 UIA Driver Server" /d "%~dp0drivers\uia-driver-server" "%~dp0runtime\dotnet\dotnet.exe" Uia.DriverServer.dll
start "G4 UIA Recorder" /d "%~dp0bot-utilities\uia-peek-win-x64" "%~dp0runtime\dotnet\dotnet.exe" UiaPeek.dll

set "EXTENSION_ID=g4-api.g4-engine-client"
set "VS_CODE_EXE=%~dp0bot-utilities\vs-code\Code.exe"
set "VS_CODE_CLI=%~dp0bot-utilities\vs-code\bin\code.cmd"
set "VSIX_DIR=%~dp0bot-utilities\vsixs"
set "VSIX_FILE="

if not exist "%VS_CODE_CLI%" (
    echo Bundled VS Code CLI was not found: "%VS_CODE_CLI%"
    goto LaunchVsCode
)

"%VS_CODE_CLI%" --list-extensions | findstr /i /x "%EXTENSION_ID%" >nul
if %errorlevel% equ 0 goto LaunchVsCode

for /f "delims=" %%F in ('dir /b /a-d /o-n "%VSIX_DIR%\%EXTENSION_ID%*.vsix" 2^>nul') do (
    set "VSIX_FILE=%VSIX_DIR%\%%F"
    goto InstallExtension
)

echo VSIX file was not found: "%VSIX_DIR%\%EXTENSION_ID%*.vsix"
goto LaunchVsCode

:InstallExtension
"%VS_CODE_CLI%" --install-extension "%VSIX_FILE%"
if errorlevel 1 echo Failed to install VS Code extension: "%VSIX_FILE%"

:LaunchVsCode
if exist "%VS_CODE_EXE%" (
    start "" "%VS_CODE_EXE%"
) else (
    echo Bundled VS Code executable was not found: "%VS_CODE_EXE%"
)
