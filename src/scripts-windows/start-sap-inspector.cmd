@echo off
cd /d "%~dp0bot-utilities\sap-inspector-win-x64"
"..\..\runtime\dotnet\dotnet.exe" Sap.DriverServer.Inspector.dll
