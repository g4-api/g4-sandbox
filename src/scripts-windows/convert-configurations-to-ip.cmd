@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "TARGET_HOST=%~1"

if "%TARGET_HOST%"=="" for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1).IPv4Address.IPAddress"`) do set "TARGET_HOST=%%a"
if "%TARGET_HOST%"=="" (
    echo ERROR: could not detect an IPv4 address and no IP argument was given.
    exit /b 1
)

set "CONFIG_DIR=%SCRIPT_DIR%selenium-grid\configurations"

echo Converting relay urls in "%CONFIG_DIR%\*.toml" to host %TARGET_HOST%
powershell -NoProfile -Command "Get-ChildItem -Path $env:CONFIG_DIR -Filter *.toml | ForEach-Object { $content = Get-Content -LiteralPath $_.FullName -Raw; $updated = $content -replace '(url\s*=\s*\x22https?://)[^:/\x22]+', ('${1}' + $env:TARGET_HOST); if ($updated -ne $content) { [System.IO.File]::WriteAllText($_.FullName, $updated); Write-Host ('  Updated:   ' + $_.Name) } else { Write-Host ('  Unchanged: ' + $_.Name) } }"
