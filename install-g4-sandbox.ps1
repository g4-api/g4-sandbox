$ErrorActionPreference = 'SilentlyContinue'

$repoUrl     = 'https://github.com/g4-api/g4-sandbox.git'
$rootWorkDir = Join-Path $env:TEMP 'g4-sandbox-bootstrap'
$repoDir     = Join-Path $rootWorkDir 'repo'
$srcDir      = Join-Path $repoDir 'src'
$toolsDir    = Join-Path $rootWorkDir 'tools'
$psDir       = Join-Path $toolsDir 'powershell'
$psZip       = Join-Path $toolsDir 'powershell.zip'
$outputDir   = 'C:\g4-sandbox'

function Write-Log {
    param([string]$Message)
    Write-Host "[+] $Message"
}

function Remove-Workdir {
    if (Test-Path $rootWorkDir) {
        Remove-Item -Path $rootWorkDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Confirm-Windows {
    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        throw 'This installer can only run on Windows.'
    }
}

function Get-PowerShellArchitecture {
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        throw 'x86 operating systems are not supported.'
    }

    $arch = if ($env:PROCESSOR_ARCHITEW6432) {
        $env:PROCESSOR_ARCHITEW6432
    }
    else {
        $env:PROCESSOR_ARCHITECTURE
    }

    switch ($arch.ToUpperInvariant()) {
        'ARM64' { return 'win-arm64' }
        'AMD64' { return 'x64' }
        default { throw "Unsupported architecture: $arch" }
    }
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        return
    }

    throw "git is required but was not found in PATH."
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
        & $PwshPath `
            -NoLogo `
            -NoProfile `
            -File            '.\Publish-G4Sandbox.ps1' `
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
    Clone-Repo
    Publish-Sandbox -PwshPath 'powershell'
    Write-Log 'Done'
}
finally {
    Remove-Workdir
}