@echo off
cd /d "%~dp0bot-utilities\chromium-recorder-x64"
"..\..\runtime\dotnet\dotnet.exe" G4.Recorders.Chromium.dll
