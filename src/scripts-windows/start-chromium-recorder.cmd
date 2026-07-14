@echo off
cd /d "%~dp0bot-utilities\chromium-peek-x64"
"..\..\runtime\dotnet\dotnet.exe" ChromiumPeek.dll
