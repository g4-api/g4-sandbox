<#
.SYNOPSIS
    Downloads a VS Code portable build for a specific version or the latest stable release, and extracts it into a destination directory.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
param(
    # Operating system selector.
    [ValidateSet("Linux", "MacOs", "Windows")]
    [string]$OperatingSystem,

    # Directory used to store the downloaded archive file.
    [string]$ArchiveDirectory,

    # Destination directory where the archive will be extracted.
    [string]$DestinationDirectory,

    # VS Code version to install.
    #
    # Notes:
    #   - Expected format: "1.96.2"
    #   - If not specified, the function installs the latest stable version.
    #   - If specified but not found in the stable releases list, it falls back to latest.
    [string]$Version,

    # When specified, removes the destination directory before extraction.
    [Switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Clean the destination directory if explicitly requested.
#
# Behavior:
#   - Removes the directory and all its contents
#   - Only executed when -Clean is specified
if ($Clean -and (Test-Path -Path $DestinationDirectory)) {
    Write-Host "Clean installation requested. Removing existing destination directory: '$($DestinationDirectory)'" -ForegroundColor DarkGray
    $ProgressPreference = 'SilentlyContinue'
    Remove-Item `
        -Path    $DestinationDirectory `
        -Recurse `
        -Force
    $ProgressPreference = 'Continue'
}

# VS Code stable releases endpoint.
#
# Notes:
#   - Returns a JSON array of version strings (newest first)
$vscodeReleasesUrl = 'https://update.code.visualstudio.com/api/releases/stable'

# Define HTTP headers.
#
# Notes:
#   - A User-Agent header reduces the likelihood of being blocked by upstream servers
$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
}

# Normalize the operating system identifier and choose:
#   - The VS Code "platform" identifier (x64 only)
#   - The expected archive extension
#
# Notes:
#   - Intentionally use portable archives (no installers):
#       * Windows: zip
#       * macOS:   zip
#       * Linux:   tar.gz
$platformId = [string]::Empty
$archiveExtention = [string]::Empty

switch ($OperatingSystem.ToLower()) {
    "macos" {
        $platformId = "darwin-universal"
        $archiveExtention = "zip"
    }
    "linux" {
        $platformId = "linux-x64"
        $archiveExtention = "tar.gz"
    }
    default {
        $platformId = "win32-x64-archive"
        $archiveExtention = "zip"
    }
}

# Retrieve the VS Code stable releases list.
Write-Host "Retrieving VS Code stable releases list: $($vscodeReleasesUrl)" -ForegroundColor DarkGray

$releasesResponse = Invoke-WebRequest `
    -Uri            $vscodeReleasesUrl `
    -Headers        $headers `
    -Method         Get `
    -UseBasicParsing

$releaseVersions = $releasesResponse.Content | ConvertFrom-Json

if (-not $releaseVersions -or $releaseVersions.Count -lt 1) {
    Write-Warning "VS Code releases list is empty or could not be parsed from '$($vscodeReleasesUrl)'."
    return
}

# Resolve version:
#   - If Version was specified: exact match against the list, otherwise fallback to latest
#   - If Version not specified: pick latest (first item)
$resolvedVersion = [string]::Empty

if ([string]::IsNullOrWhiteSpace($Version)) {
    $resolvedVersion = [string]$releaseVersions[0]
    Write-Host "No version specified. Using latest stable VS Code version: $($resolvedVersion)" -ForegroundColor Cyan
}
else {
    $match = $releaseVersions | Where-Object { $_ -eq $Version } | Select-Object -First 1

    if ($match) {
        $resolvedVersion = [string]$match
        Write-Host "Requested version found. Using VS Code version: $($resolvedVersion)" -ForegroundColor DarkGray
    }
    else {
        $resolvedVersion = [string]$releaseVersions[0]
        Write-Host "Requested version '$($Version)' was not found in stable releases. Falling back to latest: $($resolvedVersion)" -ForegroundColor Cyan
    }
}

# Build the VS Code download URL for the resolved version and platform.
#
# Notes:
#   - Format: https://update.code.visualstudio.com/<version>/<platform>/stable
$downloadUrl = "https://update.code.visualstudio.com/$($resolvedVersion)/$($platformId)/stable"

# Build a deterministic archive filename.
$archiveFileName = "vscode-$($resolvedVersion)-$($platformId).$($archiveExtention)"
$archivePath = Join-Path -Path $ArchiveDirectory -ChildPath $archiveFileName

Write-Host "Downloading VS Code ($($resolvedVersion), $($platformId)) from: $($downloadUrl)" -ForegroundColor DarkGray
Write-Host "Archive output: $($archivePath)" -ForegroundColor DarkGray

Invoke-WebRequest `
    -Uri                $downloadUrl `
    -Headers            $headers `
    -Method             Get `
    -OutFile            $archivePath `
    -MaximumRedirection 10 `
    -UseBasicParsing

if (-not (Test-Path -Path $archivePath)) {
    Write-Warning "Download failed. Archive was not created at '$($archivePath)'."
    return
}

Write-Host "Extracting archive into staging directory: $($DestinationDirectory)" -ForegroundColor DarkGray

if ($archiveExtention -eq "zip") {
    Expand-Archive `
        -Path            $archivePath `
        -DestinationPath $DestinationDirectory `
        -Force
}
else {
    # Linux/macOS tar.gz extraction (requires tar on PATH).
    #
    # Notes:
    #   - -x: extract
    #   - -z: gzip
    #   - -f: file
    New-Item `
        -Path $DestinationDirectory `
        -ItemType Directory `
        -Force `
    | Out-Null

    tar -xzf $archivePath -C $DestinationDirectory
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "tar extraction failed with exit code $($LASTEXITCODE)."
        return
    }

    # Flatten the extracted folder structure.
    #
    # Notes:
    #   - VS Code archives typically extract into a single top-level directory:
    #       vscode-<version>-<os>-x64
    #   - This function moves all contents up one level to place VS Code files
    #     directly under the destination directory
    $topLevelDirectory = Get-ChildItem -Path $DestinationDirectory -Directory |
    Sort-Object Name |
    Select-Object -First 1

    if (-not $topLevelDirectory) {
        Write-Warning "No extracted VS Code directory was found in '$($DestinationDirectory)'"
        return
    }

    Write-Host "Flattening extracted layout by moving contents from '$($topLevelDirectory.FullName)' to '$($DestinationDirectory)'" -ForegroundColor DarkGray

    # Move all extracted contents (files + folders) up one level.
    Get-ChildItem -Path $topLevelDirectory.FullName -Force | Move-Item -Destination $DestinationDirectory -Force

    # Remove the now-empty top-level extracted directory.
    $ProgressPreference = 'SilentlyContinue'
    Remove-Item -Path $topLevelDirectory.FullName -Force
    $ProgressPreference = 'Continue'
}

Write-Host "VS Code deployed successfully."         -ForegroundColor Cyan
Write-Host "Version:      $($resolvedVersion)"      -ForegroundColor DarkGray
Write-Host "Platform:     $($platformId)"           -ForegroundColor DarkGray
Write-Host "Destination:  $($DestinationDirectory)" -ForegroundColor DarkGray
Write-Host "Archive:      $($archivePath)"          -ForegroundColor DarkGray

