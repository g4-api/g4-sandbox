@echo off
start "G4 Hub" /d "%~dp0g4-hub" "%~dp0runtime\dotnet\dotnet.exe" G4.Services.Hub.dll
start "G4 UIA Driver Server" /d "%~dp0drivers\uia-driver-server" "%~dp0runtime\dotnet\dotnet.exe" Uia.DriverServer.dll
start "G4 UIA Recorder" /d "%~dp0bot-utilities\uia-peek-win-x64" "%~dp0runtime\dotnet\dotnet.exe" UiaPeek.dll
start "" "%~dp0bot-utilities\vs-code\Code.exe"