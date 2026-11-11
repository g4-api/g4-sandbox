@echo off
cd /d "%~dp0bot-utilities\sap-recorder-win-x64"
"..\..\runtime\dotnet\dotnet.exe" G4.Recorders.Sap.dll
