<#
.SYNOPSIS
    Downloads a .NET SDK archive for a specific major version and operating system, and extracts it into a destination directory.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
param(
    # .NET major version to install (example: "8", "9", "10").
    # The function resolves a channel version in the form "<major>.0".
    [string]$Version,

    # Operating system selector used when resolving the .NET SDK asset.
    # Valid values map to the download naming format used by Microsoft.
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

# Ensure the archive directory exists.
# `-Force` creates the directory if it does not exist.
New-Item -Path $ArchiveDirectory -ItemType Directory -Force | Out-Null

# Define HTTP headers.
#
# Notes:
#   - A User-Agent header reduces the likelihood of being blocked by upstream servers
#   - This is an unauthenticated request
$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
}

# Download the official .NET release index metadata.
#
# This endpoint contains a list of supported "channels" (for example: 8.0, 9.0, 10.0),
# each with a corresponding releases.json URL that contains detailed SDK/runtime files.
$releasesIndexUrl = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/releases-index.json"

Write-Host "Retrieving .NET releases index metadata: $($releasesIndexUrl)" -ForegroundColor DarkGray

$response = Invoke-WebRequest `
    -Uri           $releasesIndexUrl `
    -Headers       $headers `
    -Method        Get `
    -UseBasicParsing

if (-not $response -or $response.StatusCode -ge 400) {
    Write-Warning "Failed to retrieve .NET releases index metadata from: $($releasesIndexUrl)"
    return
}

# Parse the metadata JSON response.
$metadata = $response.Content | ConvertFrom-Json

# Resolve the requested channel version.
#
# Notes:
#   - This function treats the provided Version as a major version
#   - Channel version is expected in the form "<major>.0"
$requestedChannelVersion = "$($Version).0"

# Find the matching release channel entry.
# The channel provides a releases.json URL which contains the downloadable SDK files.
$channel = $metadata.'releases-index' |
Where-Object { $_.'channel-version' -eq $requestedChannelVersion } |
Select-Object -First 1

if (-not $channel) {
    Write-Warning "No matching .NET channel was found for channel version '$($requestedChannelVersion)'."
    return
}

$channelUrl = $channel.'releases.json'

if ([string]::IsNullOrWhiteSpace($channelUrl)) {
    Write-Warning "The resolved .NET channel entry for '$($requestedChannelVersion)' did not include a releases.json URL."
    return
}

# Normalize the operating system identifier to match the asset naming format.
#
# Notes:
#   - Microsoft uses "osx" for MacOS in many SDK file names
#   - Windows uses "win"
#   - Linux uses "linux"
$os = [string]::Empty
switch ($OperatingSystem.ToLower()) {
    "macos" { $os = "osx" }
    "linux" { $os = "linux" }
    default { $os = "win" }
}

# Download the channel-specific releases.json metadata.
Write-Host "Retrieving .NET channel release metadata: $($channelUrl)" -ForegroundColor DarkGray

$response = Invoke-WebRequest `
    -Uri           $channelUrl `
    -Method        Get `
    -UseBasicParsing

if (-not $response -or $response.StatusCode -ge 400) {
    Write-Warning "Failed to retrieve .NET channel release metadata from: $($channelUrl)"
    return
}

# Parse the releases.json response and select the latest release entry.
#
# Notes:
#   - releases[0] is assumed to be the latest release in the channel
#   - The code selects SDK files only (not runtimes)
$channelMetadata = $response.Content | ConvertFrom-Json
$latestRelease = $channelMetadata.releases[0]

if (-not $latestRelease -or -not $latestRelease.sdk -or -not $latestRelease.sdk.files) {
    Write-Warning "The .NET channel metadata did not include expected SDK file information."
    return
}

# Select the first matching x64 archive for the requested operating system.
#
# Notes:
#   - The pattern matches either .zip or .tar.gz
#   - Expand-Archive supports .zip; .tar.gz requires a different extraction approach
$releaseFile = $latestRelease.sdk.files | Where-Object { $_.url -match "$($os)-x64\.(zip|tar\.gz)" } | Select-Object -First 1

if (-not $releaseFile -or -not $releaseFile.url) {
    Write-Warning "No matching SDK archive URL was found for operating system '$($OperatingSystem)' (x64)."
    return
}

$downloadUrl = $releaseFile.url

# Derive the file name from the download URL.
# A fallback file name is used if URL parsing does not produce a file name.
$fileName = [System.IO.Path]::GetFileName([Uri]$downloadUrl)
if ([string]::IsNullOrWhiteSpace($fileName)) {
    $fileName = "download-$([Guid]::NewGuid().ToString('N')).bin"
}

$outFile = Join-Path -Path $ArchiveDirectory -ChildPath $fileName

Write-Host "Downloading .NET SDK archive to: '$($outFile)'" -ForegroundColor DarkGray

try {
    Invoke-WebRequest `
        -Uri           $downloadUrl `
        -Method        Get `
        -OutFile       $outFile `
        -Headers       $headers `
        -UseBasicParsing
}
catch {
    Write-Warning "Download failed for: $($downloadUrl)"
    Write-Warning $_.Exception.Message
    return
}

Write-Host "Archive saved in: '$($ArchiveDirectory)'" -ForegroundColor DarkGray

# Extract the archive into the destination directory.
#
# Notes:
#   - Expand-Archive supports .zip
#   - If the resolved archive is .tar.gz, this extraction step will not succeed
Write-Host "Extracting archive '$($outFile)' into destination directory: '$($DestinationDirectory)'" -ForegroundColor Cyan

$outFileLower = $outFile.ToLowerInvariant()

New-Item `
    -Path $DestinationDirectory `
    -ItemType Directory `
    -Force `
| Out-Null

if ($outFileLower.EndsWith(".zip")) {

    # -Force ensures existing files are overwritten if present.
    Expand-Archive `
        -Path            $outFile `
        -DestinationPath $DestinationDirectory `
        -Force
}
elseif ($outFileLower.EndsWith(".tar.gz") -or $outFileLower.EndsWith(".tgz") -or $outFileLower.EndsWith(".tar.xz")) {

    # Use tar for tar-based archives.
    #
    # Notes:
    #   - tar is available by default on most Linux/macOS distributions
    #   - On Windows PowerShell 5, tar may be available on newer Windows builds;
    #     if not, users should install a tar-capable tool or use the Windows zip variant.
    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) {
        Write-Warning "Cannot extract tar archive because 'tar' was not found on PATH. Archive: '$($outFile)'"
        return
    }
    
    & tar -xf $outFile -C $DestinationDirectory
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "tar extraction failed for: '$($outFile)' (exit code: $($LASTEXITCODE))"
        return
    }
}
else {
    Write-Warning "Unsupported archive format for: '$($outFile)'."
    return
}

