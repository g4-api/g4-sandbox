<#
.SYNOPSIS
    Downloads the official Python installer (Windows/macOS only) for a specific version or the latest stable release.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
param(
    # Operating system selector used when matching the installer file.
    [ValidateSet("Linux", "MacOs", "Windows")]
    [string]$OperatingSystem,

    # Destination directory where the installer file will be saved.
    [string]$DestinationDirectory,

    # Python version to download.
    #
    # Notes:
    #   - Expected format: "3.12.4"
    #   - If not specified (or not found), the latest stable Python 3 release is used.
    [string]$Version,

    # When specified, removes the destination directory before download.
    [Switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Python provides no official binary installer for Linux (source only).
# Treat Linux as a no-op so the pipeline can call this unconditionally.
if ($OperatingSystem -eq "Linux") {
    Write-Warning "Python does not provide an official Linux installer (source only). Skipping Python installer download."
    return
}

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

# Ensure the destination directory exists.
# `-Force` creates the directory if it does not exist.
New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null

# Define HTTP headers.
#
# Notes:
#   - A User-Agent header reduces the likelihood of being blocked by upstream servers
#   - This is an unauthenticated request
$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
}

# Retrieve the published Python releases from the downloads JSON API.
#
# Notes:
#   - Each entry includes: name (e.g. "Python 3.12.4"), version (2 or 3),
#     pre_release (bool), is_published (bool), resource_uri (.../release/<id>/)
$releasesUrl = "https://www.python.org/api/v2/downloads/release/?is_published=true"

Write-Host "Retrieving Python releases metadata: $($releasesUrl)" -ForegroundColor DarkGray

$response = Invoke-WebRequest `
    -Uri            $releasesUrl `
    -Headers        $headers `
    -Method         Get `
    -UseBasicParsing

if (-not $response -or $response.StatusCode -ge 400) {
    Write-Warning "Failed to retrieve Python releases metadata from: $($releasesUrl)"
    return
}

$releases = $response.Content | ConvertFrom-Json

if (-not $releases -or $releases.Length -eq 0) {
    Write-Warning "Python releases API returned no entries."
    return
}

# Keep only stable Python 3 releases and project a clean version string.
#
# Notes:
#   - 'version' is the major series indicator (3 = Python 3)
#   - 'pre_release' excludes alpha/beta/rc builds
#   - The version string is parsed out of the 'name' field ("Python 3.12.4")
$candidates = $releases |
Where-Object { $_.version -eq 3 -and -not $_.pre_release } |
ForEach-Object {
    $versionString = ($_.name -replace '^\s*Python\s+', '').Trim()
    [PSCustomObject]@{
        VersionString = $versionString
        ResourceUri   = $_.resource_uri
    }
} |
Where-Object { $_.VersionString -match '^\d+\.\d+\.\d+$' }

if (-not $candidates -or $candidates.Length -eq 0) {
    Write-Warning "No stable Python 3 releases were resolved from the releases API."
    return
}

# Resolve the release to download.
#
# Behavior:
#   - If -Version is provided: exact match, otherwise fall back to latest
#   - If -Version is not provided: pick the highest version
$selected = $null

if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $selected = $candidates | Where-Object { $_.VersionString -eq $Version.Trim() } | Select-Object -First 1
    if (-not $selected) {
        Write-Host "Requested Python version not found: '$($Version)'. Falling back to latest stable release." -ForegroundColor Cyan
    }
}

if (-not $selected) {
    $selected = $candidates | Sort-Object { [version]$_.VersionString } -Descending | Select-Object -First 1
}

Write-Host "Resolved Python version: $($selected.VersionString)" -ForegroundColor DarkGray

# Extract the numeric release id from the resource URI (.../release/<id>/).
$releaseId = [regex]::Match([string]$selected.ResourceUri, '(\d+)/?$').Groups[1].Value

if ([string]::IsNullOrWhiteSpace($releaseId)) {
    Write-Warning "Could not resolve a release id from resource URI: '$($selected.ResourceUri)'."
    return
}

# Retrieve the files attached to the resolved release.
$releaseFilesUrl = "https://www.python.org/api/v2/downloads/release_file/?release=$($releaseId)"

Write-Host "Retrieving Python release files metadata: $($releaseFilesUrl)" -ForegroundColor DarkGray

$filesResponse = Invoke-WebRequest `
    -Uri            $releaseFilesUrl `
    -Headers        $headers `
    -Method         Get `
    -UseBasicParsing

if (-not $filesResponse -or $filesResponse.StatusCode -ge 400) {
    Write-Warning "Failed to retrieve Python release files metadata from: $($releaseFilesUrl)"
    return
}

$releaseFiles = $filesResponse.Content | ConvertFrom-Json

if (-not $releaseFiles -or $releaseFiles.Length -eq 0) {
    Write-Warning "Python release files API returned no entries for release id '$($releaseId)'."
    return
}

# Select the OS-appropriate installer by URL.
#
# Notes:
#   - Windows: full offline installer 'python-<ver>-amd64.exe'
#     (the '-amd64.exe$' anchor excludes '-amd64-webinstall.exe' and the embed zip)
#   - MacOs:   universal2 installer 'python-<ver>-macos11.pkg'
$assetPattern = if ($OperatingSystem -eq "Windows") { '-amd64\.exe$' } else { '\.pkg$' }

$installerFile = $releaseFiles |
Where-Object { $_.url -match $assetPattern } |
Select-Object -First 1

if (-not $installerFile -or [string]::IsNullOrWhiteSpace($installerFile.url)) {
    Write-Warning "No Python installer matching pattern '$($assetPattern)' was found for '$($OperatingSystem)' (version $($selected.VersionString))."
    return
}

$downloadUrl = $installerFile.url

# Resolve the output file name from the URL (keep the original installer name).
# A fallback file name is used if URL parsing does not produce a file name.
$fileName = [System.IO.Path]::GetFileName([Uri]$downloadUrl)
if ([string]::IsNullOrWhiteSpace($fileName)) {
    $fileName = "python-installer-$([Guid]::NewGuid().ToString('N')).bin"
}

$outFile = Join-Path -Path $DestinationDirectory -ChildPath $fileName

Write-Host "Downloading Python installer to: '$($outFile)'" -ForegroundColor DarkGray

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

Write-Host "Python installer download completed. Destination directory: '$($DestinationDirectory)'" -ForegroundColor Cyan

