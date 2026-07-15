@echo off
setlocal

set "EXTENSION_ID=g4-api.g4-engine-client"
set "VS_CODE_EXE=%~dp0bot-utilities\vs-code\Code.exe"
set "VS_CODE_CLI=%~dp0bot-utilities\vs-code\bin\code.cmd"
set "VSIX_DIR=%~dp0bot-utilities\vsixs"
set "VSIX_FILE="
set "INSTALLED_VERSION="
set "BUNDLED_VERSION="

if not exist "%VS_CODE_CLI%" (
    echo Bundled VS Code CLI was not found: "%VS_CODE_CLI%"
    goto LaunchVsCode
)

for /f "delims=" %%F in ('dir /b /a-d /o-n "%VSIX_DIR%\%EXTENSION_ID%*.vsix" 2^>nul') do (
    set "VSIX_FILE=%VSIX_DIR%\%%F"
    goto FindInstalledVersion
)

echo VSIX file was not found: "%VSIX_DIR%\%EXTENSION_ID%*.vsix"
goto LaunchVsCode

:FindInstalledVersion
for /f "tokens=1,2 delims=@" %%A in ('call "%VS_CODE_CLI%" --list-extensions --show-versions 2^>nul') do (
    if /i "%%A"=="%EXTENSION_ID%" set "INSTALLED_VERSION=%%B"
)

if not defined INSTALLED_VERSION (
    echo Installing VS Code extension from "%VSIX_FILE%".
    goto InstallExtension
)

for /f "delims=" %%V in ('powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; $archive = [System.IO.Compression.ZipFile]::OpenRead($env:VSIX_FILE); try { $entry = $archive.GetEntry('extension/package.json'); if ($null -eq $entry) { exit 1 }; $reader = [System.IO.StreamReader]::new($entry.Open()); try { $manifest = ConvertFrom-Json -InputObject $reader.ReadToEnd(); [Console]::Write($manifest.version) } finally { $reader.Dispose() } } finally { $archive.Dispose() }" 2^>nul') do set "BUNDLED_VERSION=%%V"

if not defined BUNDLED_VERSION (
    echo Could not read the bundled extension version from "%VSIX_FILE%".
    goto LaunchVsCode
)

powershell.exe -NoLogo -NoProfile -NonInteractive -Command "try { if ([version]$env:BUNDLED_VERSION -gt [version]$env:INSTALLED_VERSION) { exit 0 }; exit 1 } catch { exit 2 }"
if errorlevel 2 (
    echo Could not compare installed version "%INSTALLED_VERSION%" with bundled version "%BUNDLED_VERSION%".
    goto LaunchVsCode
)
if errorlevel 1 goto LaunchVsCode

echo Updating VS Code extension from %INSTALLED_VERSION% to %BUNDLED_VERSION%.

:InstallExtension
call "%VS_CODE_CLI%" --install-extension "%VSIX_FILE%"
if errorlevel 1 echo Failed to install VS Code extension: "%VSIX_FILE%"

:LaunchVsCode
if exist "%VS_CODE_EXE%" (
    start "" "%VS_CODE_EXE%"
) else (
    echo Bundled VS Code executable was not found: "%VS_CODE_EXE%"
)

endlocal
