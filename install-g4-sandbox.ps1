$ErrorActionPreference = 'Stop'

$repoUrl = 'https://github.com/g4-api/g4-sandbox.git'
$rootWorkDir = Join-Path $env:TEMP 'g4-sandbox-bootstrap'
$repoDir = Join-Path $rootWorkDir 'repo'
$srcDir = Join-Path $repoDir 'src'
$toolsDir = Join-Path $rootWorkDir 'tools'
$psDir = Join-Path $toolsDir 'powershell'
$psZip = Join-Path $toolsDir 'powershell.zip'
$outputDir = 'C:\g4-sandbox'

function Write-Log {
    param([string]$Message)
    Write-Host ""
    Write-Host "[+] $Message"
}

function Remove-Workdir {
    if (Test-Path $rootWorkDir) {
        Remove-Item -Path $rootWorkDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-PowerShellArchitecture {
    $arch = "$env:PROCESSOR_ARCHITEW6432"
    if (-not $arch) {
        $arch = "$env:PROCESSOR_ARCHITECTURE"
    }

    switch ($arch.ToUpperInvariant()) {
        'AMD64' { return 'x64' }
        'ARM64' { return 'win-arm64' }
        'X86'   { throw 'x86 is not supported.' }
        default { throw "Unsupported architecture: $arch" }
    }
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        return
    }

    throw "git is required but was not found in PATH."
}

function Download-PortablePowerShell {
    $arch = Get-PowerShellArchitecture
    $version = '7.6.0'

    if ($arch -eq 'x64') {
        $psFile = "PowerShell-$version-win-x64.zip"
    }
    elseif ($arch -eq 'win-arm64') {
        $psFile = "PowerShell-$version-win-arm64.zip"
    }
    else {
        throw "Unsupported architecture mapping: $arch"
    }

    $psUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$version/$psFile"

    Write-Log "Downloading portable PowerShell $version for $arch"

    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $psDir -Force | Out-Null

    Invoke-WebRequest -Uri $psUrl -OutFile $psZip -UseBasicParsing

    Expand-Archive -Path $psZip -DestinationPath $psDir -Force

    $pwshPath = Join-Path $psDir 'pwsh.exe'
    if (-not (Test-Path $pwshPath)) {
        throw "Portable pwsh.exe was not found after extraction."
    }

    return $pwshPath
}

function Clone-Repo {
    Write-Log "Cloning g4-sandbox"
    New-Item -ItemType Directory -Path $rootWorkDir -Force | Out-Null
    git clone --depth 1 $repoUrl $repoDir | Out-Host
}

function Publish-Sandbox {
    param([string]$PwshPath)

    Write-Log "Publishing G4 sandbox to $outputDir"

    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Push-Location $srcDir
    try {
        & $PwshPath -NoLogo -NoProfile -File '.\Publish-G4Sandbox.ps1' `
            -OperatingSystem 'Windows' `
            -OutputDirectory $outputDir
    }
    finally {
        Pop-Location
    }
}

try {
    Remove-Workdir
    Ensure-Git
    $pwshPath = Download-PortablePowerShell
    Clone-Repo
    Publish-Sandbox -PwshPath $pwshPath
    Write-Log 'Done'
}
finally {
    Remove-Workdir
}