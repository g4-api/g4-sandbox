#requires -Version 5.1

<#
.SYNOPSIS
    Installs a self-contained Gitea server and one local Windows host runner.

.DESCRIPTION
    This unattended installer:
      - Resolves the latest stable Gitea and Gitea Runner versions.
      - Downloads the official Windows AMD64 binaries.
      - Verifies both binaries with the official SHA-256 files.
      - Stores configuration, SQLite, repositories, LFS, logs, home and temp
        data below one portable installation directory.
      - Binds Gitea to all IPv4 interfaces on port 3000.
      - Creates the requested administrator account without a forced reset.
      - Generates a global runner-registration token using Gitea's CLI.
      - Registers and starts one local runner with the windows:host label.
      - Creates one-click start and stop scripts.

    The registration token is never displayed or saved as a separate file.

    IMPORTANT: windows:host Actions jobs execute directly on the Windows host
    with the permissions of the user running the runner. The Gitea files are
    portable and contained, but host-mode workflow code is not sandboxed.

    The installer does not create a Windows service, scheduled task, registry
    entry or firewall rule. Git for Windows must already be available on PATH, or
    the bundled portable Git must be supplied with -GitRoot (a directory that
    contains a MinGit cmd\git.exe).

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-gitea-portable-windows.ps1

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-gitea-portable-windows.ps1 `
        -InstallRoot 'D:\portable\gitea'

.NOTES
    Default URL:      http://localhost:3000/
    Default username: g4-admin
    Default password: sk-12345

    The password is intentionally embedded because it was explicitly requested.
    A partial installation made by this script is resumed automatically. An
    existing registered runner is never overwritten.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$InstallRoot = 'E:\garbage\gitea-portable',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AdminUser = 'g4-admin',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AdminPassword = 'sk-12345',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AdminEmail = 'admin@gitea.local',

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$HttpPort = 3000,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Get-LatestStableVersion {
    param([Parameter(Mandatory)][string]$VersionUri)

    $releaseInfo = Invoke-RestMethod -Uri $VersionUri -UseBasicParsing
    $version = [string]$releaseInfo.latest.version

    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "The latest stable version could not be resolved from $VersionUri"
    }

    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        throw "The resolved version '$version' is not a stable semantic version."
    }

    return $version
}

function Get-LatestStableDirectoryVersion {
    param([Parameter(Mandatory)][string]$DirectoryUri)

    $response = Invoke-WebRequest -Uri $DirectoryUri -UseBasicParsing
    $matches = [regex]::Matches(
        [string]$response.Content,
        '(?i)href\s*=\s*["''](?:[^"'']*/)?(\d+\.\d+\.\d+)/["'']'
    )

    $versions = @(
        $matches |
            ForEach-Object { [version]$_.Groups[1].Value } |
            Sort-Object -Unique -Descending
    )

    if ($versions.Count -eq 0) {
        throw "No stable semantic versions were found at $DirectoryUri"
    }

    return $versions[0].ToString()
}

function Save-VerifiedDownload {
    param(
        [Parameter(Mandatory)][string]$BinaryUri,
        [Parameter(Mandatory)][string]$ChecksumUri,
        [Parameter(Mandatory)][string]$Destination
    )

    $checksumFile = "$Destination.sha256"

    try {
        Invoke-WebRequest -Uri $BinaryUri -OutFile $Destination -UseBasicParsing
        Invoke-WebRequest -Uri $ChecksumUri -OutFile $checksumFile -UseBasicParsing

        $checksumText = Get-Content -LiteralPath $checksumFile -Raw
        $hashMatch = [regex]::Match($checksumText, '(?i)\b[a-f0-9]{64}\b')

        if (-not $hashMatch.Success) {
            throw "No SHA-256 value was found in $ChecksumUri"
        }

        $expectedHash = $hashMatch.Value.ToLowerInvariant()
        $actualHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()

        if ($actualHash -ne $expectedHash) {
            throw "SHA-256 verification failed for $Destination"
        }
    }
    finally {
        Remove-Item -LiteralPath $checksumFile -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-NativeCaptured {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Operation
    )

    $previousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = 'Continue'
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0) {
        $details = ($output | Out-String).Trim()
        throw "$Operation failed with exit code $exitCode. $details"
    }

    return @($output | ForEach-Object { $_.ToString() })
}

function Invoke-NativeProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Operation,
        [switch]$Hidden
    )

    $parameters = @{
        FilePath         = $FilePath
        ArgumentList     = $Arguments
        WorkingDirectory = $WorkingDirectory
        Wait             = $true
        PassThru         = $true
    }

    if ($Hidden) {
        $parameters.WindowStyle = 'Hidden'
    }
    else {
        $parameters.NoNewWindow = $true
    }

    $process = Start-Process @parameters

    if ($process.ExitCode -ne 0) {
        throw "$Operation failed with exit code $($process.ExitCode)."
    }
}

function Get-LastValueLine {
    param(
        [Parameter(Mandatory)][string[]]$Output,
        [Parameter(Mandatory)][string]$Operation
    )

    $value = $Output |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Last 1

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Operation returned an empty value."
    }

    return $value
}

function Set-PortableEnvironment {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter()][string]$GitRoot
    )

    $env:GITEA_WORK_DIR = $Root
    $env:GITEA_CUSTOM = Join-Path $Root 'custom'
    $env:HOME = Join-Path $Root 'home'
    $env:USERPROFILE = Join-Path $Root 'home'
    $env:APPDATA = Join-Path $Root 'data\appdata'
    $env:LOCALAPPDATA = Join-Path $Root 'data\localappdata'
    $env:TEMP = Join-Path $Root 'temp'
    $env:TMP = Join-Path $Root 'temp'
    $env:XDG_CONFIG_HOME = Join-Path $Root 'home\.config'
    $env:XDG_CACHE_HOME = Join-Path $Root 'home\.cache'
    $env:XDG_DATA_HOME = Join-Path $Root 'home\.local\share'
    $env:GIT_CONFIG_GLOBAL = Join-Path $Root 'home\.gitconfig'

    # Prepend a bundled portable Git so repository operations and Actions jobs resolve
    # git.exe regardless of the host PATH. Absent -GitRoot leaves PATH untouched.
    if (-not [string]::IsNullOrWhiteSpace($GitRoot)) {
        $env:PATH = "$(Join-Path $GitRoot 'cmd');$env:PATH"
    }
}

function Restore-Environment {
    param([Parameter(Mandatory)][hashtable]$Values)

    foreach ($name in $Values.Keys) {
        if ($null -eq $Values[$name]) {
            Remove-Item -LiteralPath "Env:\$name" -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -LiteralPath "Env:\$name" -Value $Values[$name]
        }
    }
}

function Wait-Gitea {
    param(
        [Parameter(Mandatory)][int]$Port,
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 90
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $healthUri = "http://127.0.0.1:$Port/api/healthz"

    while ((Get-Date) -lt $deadline) {
        if ($Process.HasExited) {
            throw "Gitea stopped during startup with exit code $($Process.ExitCode)."
        }

        try {
            $response = Invoke-WebRequest -Uri $healthUri -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) {
                return
            }
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }

    throw "Gitea did not become healthy within $TimeoutSeconds seconds."
}

if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'This installer supports 64-bit Windows only.'
}

$gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue

if (-not [string]::IsNullOrWhiteSpace($GitRoot)) {
    $bundledGitExe = Join-Path $GitRoot 'cmd\git.exe'
    if (-not (Test-Path -LiteralPath $bundledGitExe)) {
        throw "The provided -GitRoot '$GitRoot' does not contain cmd\git.exe."
    }
    $gitCommand = Get-Item -LiteralPath $bundledGitExe
}

if (-not $gitCommand) {
    throw 'Git for Windows was not found on PATH. Install Git for Windows first or provide -GitRoot.'
}

$resolvedRoot = [IO.Path]::GetFullPath($InstallRoot)
$configPath = Join-Path $resolvedRoot 'custom\conf\app.ini'
$databasePath = Join-Path $resolvedRoot 'data\gitea.db'
$giteaExe = Join-Path $resolvedRoot 'gitea.exe'
$runnerRoot = Join-Path $resolvedRoot 'runner'
$runnerExe = Join-Path $runnerRoot 'gitea-runner.exe'
$runnerIdentity = Join-Path $runnerRoot '.runner'

if (Test-Path -LiteralPath $runnerIdentity) {
    throw "An existing runner identity was found at '$runnerIdentity'. Nothing was changed."
}

$resumePartialInstallation = Test-Path -LiteralPath $databasePath

if ($resumePartialInstallation) {
    if (-not (Test-Path -LiteralPath $giteaExe) -or -not (Test-Path -LiteralPath $configPath)) {
        throw "The database exists, but gitea.exe or app.ini is missing. Refusing to modify an inconsistent installation."
    }
}

$listener = Get-NetTCPConnection -LocalPort $HttpPort -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    throw "TCP port $HttpPort is already in use. Nothing was changed."
}

if ($resumePartialInstallation) {
    Write-Step "Resuming the partial portable installation at $resolvedRoot"
}
else {
    Write-Step "Creating portable directory structure at $resolvedRoot"
}

$directories = @(
    $resolvedRoot,
    (Join-Path $resolvedRoot 'custom\conf'),
    (Join-Path $resolvedRoot 'data\repositories'),
    (Join-Path $resolvedRoot 'data\lfs'),
    (Join-Path $resolvedRoot 'data\sessions'),
    (Join-Path $resolvedRoot 'data\appdata'),
    (Join-Path $resolvedRoot 'data\localappdata'),
    (Join-Path $resolvedRoot 'home\.config'),
    (Join-Path $resolvedRoot 'home\.cache'),
    (Join-Path $resolvedRoot 'home\.local\share'),
    (Join-Path $resolvedRoot 'log'),
    (Join-Path $resolvedRoot 'temp'),
    $runnerRoot
)

foreach ($directory in $directories) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$portableEnvironmentNames = @(
    'GITEA_WORK_DIR', 'GITEA_CUSTOM', 'HOME', 'USERPROFILE', 'APPDATA',
    'LOCALAPPDATA', 'TEMP', 'TMP', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME',
    'XDG_DATA_HOME', 'GIT_CONFIG_GLOBAL', 'PATH'
)
$originalPortableEnvironment = @{}

foreach ($name in $portableEnvironmentNames) {
    $item = Get-Item -LiteralPath "Env:\$name" -ErrorAction SilentlyContinue
    $originalPortableEnvironment[$name] = if ($item) { $item.Value } else { $null }
}

Set-PortableEnvironment -Root $resolvedRoot -GitRoot $GitRoot

try {

if ($resumePartialInstallation) {
    $installedVersionOutput = Invoke-NativeCaptured `
        -FilePath $giteaExe `
        -Arguments @('--version') `
        -Operation 'Installed Gitea version detection'
    $installedVersionText = ($installedVersionOutput | Out-String)

    if ($installedVersionText -notmatch '(?i)\bversion\s+(\d+\.\d+\.\d+)\b') {
        throw "Could not determine the installed Gitea version from: $installedVersionText"
    }

    $giteaVersion = $Matches[1]

    # Force internal calls onto IPv4 loopback. On some Windows systems,
    # localhost resolves to ::1 while HTTP_ADDR=0.0.0.0 listens only on IPv4.
    $existingConfig = Get-Content -LiteralPath $configPath -Raw
    $updatedConfig = [regex]::Replace(
        $existingConfig,
        '(?m)^LOCAL_ROOT_URL\s*=.*$',
        "LOCAL_ROOT_URL = http://127.0.0.1:$HttpPort/"
    )

    if ($updatedConfig -eq $existingConfig -and $existingConfig -notmatch '(?m)^LOCAL_ROOT_URL\s*=') {
        throw "The existing app.ini has no LOCAL_ROOT_URL setting. Refusing an unsafe automatic resume."
    }

    $updatedConfig | Set-Content -LiteralPath $configPath -Encoding UTF8
    Write-Host "Using the existing Gitea $giteaVersion database and administrator."
}
else {

Write-Step 'Resolving and downloading the latest stable Gitea release'
$giteaVersion = Get-LatestStableVersion -VersionUri 'https://dl.gitea.com/gitea/version.json'
$giteaFileName = "gitea-$giteaVersion-windows-4.0-amd64.exe"
$giteaBaseUri = "https://dl.gitea.com/gitea/$giteaVersion/$giteaFileName"

Save-VerifiedDownload `
    -BinaryUri $giteaBaseUri `
    -ChecksumUri "$giteaBaseUri.sha256" `
    -Destination $giteaExe

Write-Host "Gitea $giteaVersion downloaded and verified."

Write-Step 'Generating instance secrets and portable configuration'
$secretKey = Get-LastValueLine `
    -Output (Invoke-NativeCaptured -FilePath $giteaExe -Arguments @('generate', 'secret', 'SECRET_KEY') -Operation 'SECRET_KEY generation') `
    -Operation 'SECRET_KEY generation'

$internalToken = Get-LastValueLine `
    -Output (Invoke-NativeCaptured -FilePath $giteaExe -Arguments @('generate', 'secret', 'INTERNAL_TOKEN') -Operation 'INTERNAL_TOKEN generation') `
    -Operation 'INTERNAL_TOKEN generation'

$jwtSecret = Get-LastValueLine `
    -Output (Invoke-NativeCaptured -FilePath $giteaExe -Arguments @('generate', 'secret', 'JWT_SECRET') -Operation 'JWT_SECRET generation') `
    -Operation 'JWT_SECRET generation'

$appIni = @"
APP_NAME = Gitea Portable
RUN_MODE = prod

[repository]
ROOT = data/repositories
DEFAULT_BRANCH = main

[server]
PROTOCOL = http
DOMAIN = localhost
HTTP_ADDR = 0.0.0.0
HTTP_PORT = $HttpPort
ROOT_URL = http://localhost:$HttpPort/
PUBLIC_URL_DETECTION = auto
LOCAL_ROOT_URL = http://127.0.0.1:$HttpPort/
APP_DATA_PATH = data
DISABLE_SSH = true
LFS_START_SERVER = true
LFS_JWT_SECRET = $jwtSecret
OFFLINE_MODE = true

[database]
DB_TYPE = sqlite3
PATH = data/gitea.db

[lfs]
STORAGE_TYPE = local
PATH = data/lfs

[session]
PROVIDER = file
PROVIDER_CONFIG = data/sessions

[actions]
ENABLED = true

[service]
DISABLE_REGISTRATION = true

[log]
MODE = console,file
LEVEL = Info
ROOT_PATH = log

[security]
INSTALL_LOCK = true
SECRET_KEY = $secretKey
INTERNAL_TOKEN = $internalToken
"@

$appIni | Set-Content -LiteralPath $configPath -Encoding UTF8

$secretKey = $null
$internalToken = $null
$jwtSecret = $null

Write-Step 'Initializing the SQLite database'
Invoke-NativeProcess `
    -FilePath $giteaExe `
    -Arguments @('migrate', '--config', ('"{0}"' -f $configPath)) `
    -WorkingDirectory $resolvedRoot `
    -Operation 'Gitea database migration'

Write-Step "Creating administrator '$AdminUser'"
Invoke-NativeProcess `
    -FilePath $giteaExe `
    -Arguments @(
        'admin', 'user', 'create',
        '--config', ('"{0}"' -f $configPath),
        '--username', $AdminUser,
        '--password', $AdminPassword,
        '--email', $AdminEmail,
        '--admin',
        '--must-change-password=false'
    ) `
    -WorkingDirectory $resolvedRoot `
    -Operation 'Administrator creation' `
    -Hidden
}

Write-Step 'Resolving and downloading the latest stable Gitea Runner release'
$runnerVersion = Get-LatestStableDirectoryVersion -DirectoryUri 'https://dl.gitea.com/gitea-runner/'
$runnerFileName = "gitea-runner-$runnerVersion-windows-amd64.exe"
$runnerBaseUri = "https://dl.gitea.com/gitea-runner/$runnerVersion/$runnerFileName"

Save-VerifiedDownload `
    -BinaryUri $runnerBaseUri `
    -ChecksumUri "$runnerBaseUri.sha256" `
    -Destination $runnerExe

Write-Host "Gitea Runner $runnerVersion downloaded and verified."

Write-Step 'Starting Gitea'
$giteaProcess = Start-Process `
    -FilePath $giteaExe `
    -ArgumentList @('web', '--config', ('"{0}"' -f $configPath)) `
    -WorkingDirectory $resolvedRoot `
    -WindowStyle Hidden `
    -PassThru

try {
    Wait-Gitea -Port $HttpPort -Process $giteaProcess

    Write-Step 'Obtaining the runner registration token internally'
    $registrationToken = Get-LastValueLine `
        -Output (Invoke-NativeCaptured -FilePath $giteaExe -Arguments @('actions', 'generate-runner-token', '--config', $configPath) -Operation 'Runner token generation') `
        -Operation 'Runner token generation'

    Write-Step 'Registering the local Windows runner'
    $env:GITEA_RUNNER_REGISTRATION_TOKEN = $registrationToken

    try {
        Invoke-NativeProcess `
            -FilePath $runnerExe `
            -Arguments @(
                'register',
                '--no-interactive',
                '--instance', "http://127.0.0.1:$HttpPort/",
                '--name', 'g4-windows',
                '--labels', 'windows:host'
            ) `
            -WorkingDirectory $runnerRoot `
            -Operation 'Runner registration' `
            -Hidden
    }
    finally {
        Remove-Item Env:\GITEA_RUNNER_REGISTRATION_TOKEN -ErrorAction SilentlyContinue
        $registrationToken = $null
    }

    if (-not (Test-Path -LiteralPath $runnerIdentity)) {
        throw "Runner registration completed without creating '$runnerIdentity'."
    }
}
catch {
    if ($giteaProcess -and -not $giteaProcess.HasExited) {
        Stop-Process -Id $giteaProcess.Id -Force -ErrorAction SilentlyContinue
    }
    throw
}

Write-Step 'Creating portable start and stop launchers'

$startPortable = @'
#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$GiteaExe = Join-Path $Root 'gitea.exe'
$ConfigPath = Join-Path $Root 'custom\conf\app.ini'
$RunnerRoot = Join-Path $Root 'runner'
$RunnerExe = Join-Path $RunnerRoot 'gitea-runner.exe'

$env:GITEA_WORK_DIR = $Root
$env:GITEA_CUSTOM = Join-Path $Root 'custom'
$env:HOME = Join-Path $Root 'home'
$env:USERPROFILE = Join-Path $Root 'home'
$env:APPDATA = Join-Path $Root 'data\appdata'
$env:LOCALAPPDATA = Join-Path $Root 'data\localappdata'
$env:TEMP = Join-Path $Root 'temp'
$env:TMP = Join-Path $Root 'temp'
$env:XDG_CONFIG_HOME = Join-Path $Root 'home\.config'
$env:XDG_CACHE_HOME = Join-Path $Root 'home\.cache'
$env:XDG_DATA_HOME = Join-Path $Root 'home\.local\share'
$env:GIT_CONFIG_GLOBAL = Join-Path $Root 'home\.gitconfig'

# Put the sandbox-bundled portable Git (runtime\git) ahead of PATH so repository and
# Actions operations never depend on a host-installed Git for Windows. Falls back to
# host Git silently when the box runs standalone without runtime\git nearby.
$PortableGitBin = Join-Path $Root '..\runtime\git\cmd'
if (Test-Path -LiteralPath $PortableGitBin) {
    $env:PATH = "$PortableGitBin;$env:PATH"
}

$GiteaPath = [IO.Path]::GetFullPath($GiteaExe)
$RunnerPath = [IO.Path]::GetFullPath($RunnerExe)
$Processes = Get-CimInstance Win32_Process
$GiteaRunning = $Processes | Where-Object { $_.ExecutablePath -eq $GiteaPath }

if (-not $GiteaRunning) {
    Start-Process -FilePath $GiteaExe -ArgumentList @('web', '--config', ('"{0}"' -f $ConfigPath)) -WorkingDirectory $Root -WindowStyle Hidden
}

$Deadline = (Get-Date).AddSeconds(90)
$Healthy = $false
do {
    try {
        $Response = Invoke-WebRequest -Uri 'http://127.0.0.1:__HTTP_PORT__/api/healthz' -UseBasicParsing -TimeoutSec 3
        if ($Response.StatusCode -eq 200) {
            $Healthy = $true
            break
        }
    }
    catch {
        Start-Sleep -Seconds 1
    }
} while ((Get-Date) -lt $Deadline)

if (-not $Healthy) {
    throw 'Gitea did not become healthy within 90 seconds.'
}

$RunnerRunning = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $RunnerPath }
if (-not $RunnerRunning) {
    Start-Process -FilePath $RunnerExe -ArgumentList @('daemon', '--labels', 'windows:host') -WorkingDirectory $RunnerRoot -WindowStyle Hidden
}

Write-Host 'Gitea and its local runner are running.'
Write-Host 'Open: http://localhost:__HTTP_PORT__/'
'@

$stopPortable = @'
#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$GiteaExe = [IO.Path]::GetFullPath((Join-Path $Root 'gitea.exe'))
$RunnerExe = [IO.Path]::GetFullPath((Join-Path $Root 'runner\gitea-runner.exe'))
$ConfigPath = Join-Path $Root 'custom\conf\app.ini'

$RunnerProcesses = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $RunnerExe }
foreach ($Process in $RunnerProcesses) {
    Stop-Process -Id $Process.ProcessId -Force -ErrorAction SilentlyContinue
}

$GiteaProcesses = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $GiteaExe }
if ($GiteaProcesses) {
    $env:GITEA_WORK_DIR = $Root
    $env:GITEA_CUSTOM = Join-Path $Root 'custom'
    try {
        & $GiteaExe manager shutdown --config $ConfigPath 2>$null
    }
    catch {
        $null = $_
    }
    Start-Sleep -Seconds 2
}

$GiteaProcesses = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $GiteaExe }
foreach ($Process in $GiteaProcesses) {
    Stop-Process -Id $Process.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host 'Gitea and its local runner are stopped.'
'@

$startCommand = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-gitea.ps1"
if errorlevel 1 pause
'@

$stopCommand = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop-gitea.ps1"
if errorlevel 1 pause
'@

$startPortable = $startPortable.Replace('__HTTP_PORT__', [string]$HttpPort)

$startPortable | Set-Content -LiteralPath (Join-Path $resolvedRoot 'start-gitea.ps1') -Encoding UTF8
$stopPortable | Set-Content -LiteralPath (Join-Path $resolvedRoot 'stop-gitea.ps1') -Encoding UTF8
$startCommand | Set-Content -LiteralPath (Join-Path $resolvedRoot 'start-gitea.cmd') -Encoding ASCII
$stopCommand | Set-Content -LiteralPath (Join-Path $resolvedRoot 'stop-gitea.cmd') -Encoding ASCII

Write-Step 'Starting the local runner'
$runnerProcess = Start-Process `
    -FilePath $runnerExe `
    -ArgumentList @('daemon', '--labels', 'windows:host') `
    -WorkingDirectory $runnerRoot `
    -WindowStyle Hidden `
    -PassThru

Start-Sleep -Seconds 2
if ($runnerProcess.HasExited) {
    throw "The runner stopped immediately with exit code $($runnerProcess.ExitCode)."
}

Write-Host
Write-Host 'Installation completed successfully.' -ForegroundColor Green
Write-Host "Gitea version:  $giteaVersion"
Write-Host "Runner version: $runnerVersion"
Write-Host "Location:       $resolvedRoot"
Write-Host "URL:            http://localhost:$HttpPort/"
Write-Host "Username:       $AdminUser"
Write-Host 'Password:       configured as requested'
Write-Host "Runner:         g4-windows (windows:host)"
Write-Host
Write-Host 'Use start-gitea.cmd and stop-gitea.cmd for normal operation.'
Write-Host 'No firewall rule was created. LAN access may require a Private-network inbound rule.'
}
finally {
    Remove-Item Env:\GITEA_RUNNER_REGISTRATION_TOKEN -ErrorAction SilentlyContinue
    Restore-Environment -Values $originalPortableEnvironment
}