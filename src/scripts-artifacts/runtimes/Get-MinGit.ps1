<#
.SYNOPSIS
    Downloads a portable Git for Windows (MinGit) distribution and extracts it into a
    destination directory.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1. It resolves the
    latest git-for-windows MinGit release, downloads the canonical non-busybox 64-bit zip,
    and extracts it below the destination directory. The <destination>\cmd entry exposes
    git.exe and is the PATH addition required at runtime.

    Windows resolution is implemented here. The Linux/macOS provider is a separate script
    that has not been added yet; calling this resolver for those targets warns and skips.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
param(
    # Operating system selector used when deciding whether the Windows MinGit resolution
    # applies to this target.
    [ValidateSet("Linux", "MacOs", "Windows")]
    [string]$OperatingSystem,

    # Directory used to store the downloaded archive file.
    [string]$ArchiveDirectory,

    # Destination directory where the archive will be extracted.
    [string]$DestinationDirectory,

    # When specified, removes the destination directory before extraction.
    # This guarantees a clean, deterministic installation state.
    [Switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Enable TLS 1.2 on Windows PowerShell 5.x so GitHub and browser_download_url redirects work.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($OperatingSystem -ne 'Windows') {
    Write-Warning "Portable Git for '$($OperatingSystem)' is not resolved by this script yet; a Linux/macOS provider script will be added later. Skipping MinGit staging."
    return
}

# Clean the destination directory if explicitly requested.
if ($Clean -and (Test-Path -Path $DestinationDirectory)) {

    Write-Host "Clean installation requested. Removing existing destination directory: '$($DestinationDirectory)'" -ForegroundColor DarkGray

    $ProgressPreference = 'SilentlyContinue'
    Remove-Item `
        -Path $DestinationDirectory `
        -Recurse `
        -Force
    $ProgressPreference = 'Continue'
}

# Ensure the archive and destination directories exist.
New-Item -Path $ArchiveDirectory -ItemType Directory -Force | Out-Null
New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null

# Resolve the latest git-for-windows release, which publishes the MinGit zip asset set.
$githubApiUrl = 'https://api.github.com/repos/git-for-windows/git/releases/latest'
$headers = @{
    'Accept'     = 'application/vnd.github+json'
    'User-Agent' = "PowerShell/$($PSVersionTable.PSVersion)"
}

Write-Host "Retrieving latest MinGit release metadata from: $($githubApiUrl)" -ForegroundColor DarkGray

try {
    $response = Invoke-RestMethod `
        -Uri             $githubApiUrl `
        -Method          Get `
        -Headers         $headers `
        -UseBasicParsing `
        -ErrorAction     Stop
}
catch {
    Write-Warning "Failed to retrieve MinGit release metadata from: $($githubApiUrl)"
    Write-Warning $_.Exception.Message
    return
}

if (-not $response.tag_name) {
    Write-Warning 'GitHub API response did not include a release tag (tag_name).'
    return
}

# Pick the canonical MinGit 64-bit zip: exclude the busybox and packaged/build variants.
$asset = $response.assets |
    Where-Object { $_.name -match '^MinGit-.*-64-bit\.zip$' -and $_.name -notmatch '(?i)busybox' } |
    Sort-Object name |
    Select-Object -First 1

if (-not $asset) {
    Write-Warning "Release '$($response.tag_name)' exposed no canonical MinGit 64-bit zip asset."
    return
}

$downloadUrl = $asset.browser_download_url
$outFile = Join-Path -Path $ArchiveDirectory -ChildPath $asset.name

Write-Host "Resolved MinGit download URL: $($downloadUrl)" -ForegroundColor DarkGray
Write-Host "Downloading MinGit archive to: '$($outFile)'" -ForegroundColor DarkGray

try {
    Invoke-WebRequest `
        -Uri      $downloadUrl `
        -Method   Get `
        -OutFile  $outFile `
        -Headers  $headers `
        -UseBasicParsing
}
catch {
    Write-Warning "Download failed for: $($downloadUrl)"
    Write-Warning $_.Exception.Message
    return
}

Write-Host "Extracting archive '$($outFile)' into destination directory: '$($DestinationDirectory)'" -ForegroundColor Cyan

try {
    Expand-Archive `
        -Path            $outFile `
        -DestinationPath $DestinationDirectory `
        -Force
}
catch {
    Write-Warning "Extraction failed for: '$($outFile)'"
    Write-Warning $_.Exception.Message
    return
}

# MinGit archives extract at the root (cmd/, mingw64/, git/, LICENSE.txt) - no flattening.
$gitExe = Join-Path $DestinationDirectory 'cmd\git.exe'
if (-not (Test-Path -LiteralPath $gitExe)) {
    Write-Warning "Extracted MinGit does not contain cmd\git.exe under '$($DestinationDirectory)'."
    return
}

Write-Host "Portable Git (MinGit) installation completed. Destination directory: '$($DestinationDirectory)'" -ForegroundColor Cyan
Write-Host "Add '$($DestinationDirectory)\cmd' to PATH to expose git." -ForegroundColor DarkGray