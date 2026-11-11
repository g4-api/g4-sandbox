@echo off
cd /d "%~dp0bot-utilities\android-recorder-x64"
"..\..\runtime\dotnet\dotnet.exe" G4.Recorders.Android.dll
