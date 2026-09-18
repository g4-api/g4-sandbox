<#
.SYNOPSIS
    Downloads a Node.js distribution archive for a specific version and operating system, and extracts it into a destination directory.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
param(
    # Operating system selector used when matching the Node.js asset filename.
    # Valid values map to the file naming conventions used by nodejs.org.
    [ValidateSet("Linux", "MacOs", "Windows")]
    [string]$OperatingSystem,

    # Directory used to store the downloaded archive file.
    [string]$ArchiveDirectory,

    # Destination directory where the archive will be extracted.
    [string]$DestinationDirectory,

    # Node.js version to install.
    #
    # Notes:
    #   - Expected format: "22.11.0" (no leading "v")
    #   - The function will match against "v22.11.0" in index.json
    [string]$Version,

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

# Node.js releases metadata endpoint.
#
# Notes:
#   - Contains a JSON array of releases (version, lts flag/name, files, etc.)
#   - Example version values: "v22.11.0"
$nodejsIndexUrl = 'https://nodejs.org/dist/index.json'

# Define HTTP headers.
#
# Notes:
#   - A User-Agent header reduces the likelihood of being blocked by upstream servers
#   - This is an unauthenticated request
$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
}

# Normalize the operating system identifier and choose an archive filename suffix.
#
# Notes:
#   - These map directly to how Node.js names its official distribution artifacts.
#   - We intentionally pick formats that are most common for each OS:
#       * Windows: zip
#       * macOS:   tar.gz
#       * Linux:   tar.xz
$assetSuffix = [string]::Empty
switch ($OperatingSystem.ToLower()) {
    "macos" { 
        $assetSuffix = "darwin-x64.tar.gz"
    }
    "linux" {
        $assetSuffix = "linux-x64.tar.xz"
    }
    default {
        $assetSuffix = "win-x64.zip"
    }
}

# Ensure the archive directory exists.
# `-Force` creates the directory if it does not exist.
New-Item -Path $ArchiveDirectory -ItemType Directory -Force | Out-Null

# Ensure the destination directory exists (unless user opted to Clean, in which case
# it might have been removed and needs to be recreated for extraction).
New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null

# Retrieve the Node.js releases index JSON.
# Retrieve the Node.js releases index JSON.
#
# Notes:
#   - index.json contains an array of release objects (version, files, LTS flag, etc.)
#   - We use it to resolve the requested version or fall back to the latest
Write-Host "Retrieving Node.js releases index: $($nodejsIndexUrl)" -ForegroundColor DarkGray

$response = Invoke-WebRequest `
    -Uri            $nodejsIndexUrl `
    -Headers        $headers `
    -Method         Get `
    -UseBasicParsing

# Validate the HTTP response.
#
# Behavior:
#   - If the request fails or returns a 4xx/5xx status code, exit early
if (-not $response -or $response.StatusCode -ge 400) {
    Write-Warning ("Failed to retrieve Node.js releases index metadata from: $($nodejsIndexUrl)")
    return
}

# Parse the metadata JSON response.
#
# Notes:
#   - ConvertFrom-Json turns the JSON array into PowerShell objects
$metadata = $response.Content | ConvertFrom-Json

# Validate parsed metadata.
#
# Behavior:
#   - Exit early if the response is empty or not a valid list of releases
if (-not $metadata -or ($metadata.Length -eq 0)) {
    Write-Warning "Node.js releases index returned no entries."
    return
}

# Resolve the requested Node.js version entry.
#
# Notes:
#   - index.json uses versions in the form "vX.Y.Z"
#   - We treat $Version as "X.Y.Z" and normalize it to "vX.Y.Z"
#   - If no version was provided (or it wasn't found), we fall back to the first item
#     which is typically the most recent release.
$requestedVersion = [string]::Empty
if (-not [string]::IsNullOrWhiteSpace($Version)) {

    # Normalize the input so both "22.11.0" and "v22.11.0" work.
    $requestedVersion = if ($Version.TrimStart().StartsWith("v")) { $Version.Trim() } else { "v$($Version.Trim())" }
}

# Initialize the resolved release record.
$release = $null

# Attempt exact match lookup when a version was provided.
#
# Notes:
#   - We intentionally use exact version matching against the index entry
#   - Select-Object -First 1 ensures deterministic selection if duplicates exist
if (-not [string]::IsNullOrWhiteSpace($requestedVersion)) {
    $release = $metadata |
    Where-Object { $_.version -eq $requestedVersion } |
    Select-Object -First 1
}

# Fall back to latest release when no exact match was resolved.
#
# Notes:
#   - index.json is typically ordered newest -> oldest, so [0] is usually latest
if (-not $release) {
    if (-not [string]::IsNullOrWhiteSpace($requestedVersion)) {
        Write-Host "Requested Node.js version not found: '$($requestedVersion)'. Falling back to latest release." -ForegroundColor Cyan
    }
    else {
        Write-Host "No Node.js version provided. Using latest release from index.json." -ForegroundColor Cyan
    }

    $release = $metadata[0]
}

# Build the download URL for the selected OS and resolved version.
#
# Example:
#   https://nodejs.org/dist/v22.11.0/node-v22.11.0-win-x64.zip
$downloadUrl = "https://nodejs.org/dist/$($release.version)/node-$($release.version)-$($assetSuffix)"

Write-Host "Resolved Node.js download URL: $($downloadUrl)" -ForegroundColor DarkGray

# Resolve the output file name for the downloaded archive.
#
# Notes:
#   - The file name is derived from the URL
#   - A fallback file name is used if URL parsing does not produce a file name
$fileName = [System.IO.Path]::GetFileName([Uri]$downloadUrl)
if ([string]::IsNullOrWhiteSpace($fileName)) {
    $fileName = "download-$([Guid]::NewGuid().ToString('N')).bin"
}

# Build the full output path in the archive directory.
$outFile = Join-Path -Path $ArchiveDirectory -ChildPath $fileName

Write-Host "Downloading Node.js archive to: '$($outFile)'" -ForegroundColor DarkGray

# Download the resolved Node.js distribution archive.
#
# Notes:
#   - Any network/HTTP failure is handled in catch
#   - We use -OutFile to stream directly to disk (no memory buffering)
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

Write-Host "Archive saved in: '$($ArchiveDirectory)'" -ForegroundColor DarkGray

# Extract the archive into the destination directory.
#
# Notes:
#   - Windows uses Expand-Archive for .zip files
#   - Linux/macOS uses 'tar' for .tar.gz / .tar.xz
Write-Host "Extracting archive '$($outFile)' into destination directory: '$($DestinationDirectory)'" -ForegroundColor Cyan

$outFileLower = $outFile.ToLowerInvariant()

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

    # -x: extract, -f: file, -C: destination directory
    New-Item `
        -Path $DestinationDirectory `
        -ItemType Directory `
        -Force `
    | Out-Null
    
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

# Flatten the extracted folder structure.
#
# Notes:
#   - Node.js archives typically extract into a single top-level directory:
#       node-vX.Y.Z-<os>-x64
#   - This function moves all contents up one level to place Node.js files
#     directly under the destination directory
$topLevelDirectory = Get-ChildItem -Path $DestinationDirectory -Directory |
Sort-Object Name |
Select-Object -First 1

if (-not $topLevelDirectory) {
    Write-Warning "No extracted Node.js directory was found in '$($DestinationDirectory)'"
    return
}

Write-Host "Flattening extracted layout by moving contents from '$($topLevelDirectory.FullName)' to '$($DestinationDirectory)'" -ForegroundColor DarkGray

# Move all extracted contents (files + folders) up one level.
Get-ChildItem -Path $topLevelDirectory.FullName -Force | Move-Item -Destination $DestinationDirectory -Force

# Remove the now-empty top-level extracted directory.
$ProgressPreference = 'SilentlyContinue'
Remove-Item -Path $topLevelDirectory.FullName -Force
$ProgressPreference = 'Continue'

Write-Host "Node.js installation completed. Destination directory: '$($DestinationDirectory)'" -ForegroundColor Cyan

