@echo off
cd /d "%~dp0drivers\sap-driver-server"
"..\..\runtime\dotnet\dotnet.exe" Sap.DriverServer.dll
