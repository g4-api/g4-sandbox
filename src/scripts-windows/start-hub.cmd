@echo off
cd /d "%~dp0g4-hub"
"..\runtime\dotnet\dotnet.exe" G4.Services.Hub.dll
