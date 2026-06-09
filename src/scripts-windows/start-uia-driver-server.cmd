@echo off
cd /d "%~dp0drivers\uia-driver-server"
"..\..\runtime\dotnet\dotnet.exe" Uia.DriverServer.dll
