@echo off
rem Adds Windows Firewall rules for the programs of this sandbox, so Windows does not ask to allow them while G4
rem runs. Only administrators can change firewall rules, so Windows asks for consent once.
rem The rules of sandbox folders that no longer exist beside this one are removed.
setlocal

set "SCRIPT_DIR=%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%bot-utilities\scripts\Set-SandboxFirewallRule.ps1" -SandboxDirectory "%SCRIPT_DIR%."
exit /b %ERRORLEVEL%
