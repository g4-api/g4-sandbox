$ErrorActionPreference = 'Stop'

$GiteaRoot = 'E:\garbage\gitea-portable'
$RunnerRoot = Join-Path $GiteaRoot 'runner'
$RunnerExe = Join-Path $RunnerRoot 'gitea-runner.exe'

if (-not (Test-Path $RunnerExe)) {
    throw "Runner executable not found: $RunnerExe"
}

$SecureToken = Read-Host 'Paste the NEW registration token' -AsSecureString
$TokenPointer = [IntPtr]::Zero

try {
    $TokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureToken)
    $env:GITEA_RUNNER_REGISTRATION_TOKEN =
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($TokenPointer)

    $Arguments = @(
        'register'
        '--no-interactive'
        '--instance'
        'http://localhost:3000/'
        '--name'
        'g4-windows'
        '--labels'
        'windows:host'
    )

    $Process = Start-Process `
        -FilePath $RunnerExe `
        -ArgumentList $Arguments `
        -WorkingDirectory $RunnerRoot `
        -NoNewWindow `
        -Wait `
        -PassThru

    if ($Process.ExitCode -ne 0) {
        throw "Runner registration failed with exit code $($Process.ExitCode)."
    }
}
finally {
    Remove-Item Env:\GITEA_RUNNER_REGISTRATION_TOKEN -ErrorAction SilentlyContinue

    if ($TokenPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($TokenPointer)
    }
}

if (-not (Test-Path (Join-Path $RunnerRoot '.runner'))) {
    throw 'Registration completed without creating the .runner file.'
}

$StartRunner = @'
@echo off
setlocal
pushd "%~dp0runner"
gitea-runner.exe daemon --labels "windows:host"
set "RUNNER_EXIT=%ERRORLEVEL%"
popd
echo.
echo Gitea Runner stopped with exit code %RUNNER_EXIT%.
pause
exit /b %RUNNER_EXIT%
'@

Set-Content `
    -Path (Join-Path $GiteaRoot 'start-gitea-runner.cmd') `
    -Value $StartRunner `
    -Encoding ASCII

Write-Host
Write-Host 'Runner registration completed successfully.'
Write-Host "Created: $GiteaRoot\start-gitea-runner.cmd"