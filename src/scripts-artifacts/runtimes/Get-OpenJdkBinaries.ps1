<#
.SYNOPSIS
    Downloads the latest OpenJDK binaries for a specific operating system, and extracts them into a destination directory.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
param(
    # Operating system selector used when matching the OpenJDK asset URL.
    # Valid values map to the download link format used by jdk.java.net.
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

# OpenJDK home page used to discover the latest JDK downloads page.
$openJdkHomeUrl = 'https://openjdk.org/'

# Define HTTP headers.
#
# Notes:
#   - A User-Agent header reduces the likelihood of being blocked by upstream servers
#   - This is an unauthenticated request
$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
}

# Normalize the operating system identifier to match the naming format used in the download links.
# Default is "windows" if no value was provided.
$os = if (-not $OperatingSystem) { "windows" } else { $OperatingSystem.ToLower() }

# Ensure the archive directory exists.
# `-Force` creates the directory if it does not exist.
New-Item -Path $ArchiveDirectory -ItemType Directory -Force | Out-Null

# Retrieve the OpenJDK home page HTML.
Write-Host "Retrieving OpenJDK home page: $($openJdkHomeUrl)" -ForegroundColor DarkGray

$homeHtml = Invoke-WebRequest `
    -Uri           $openJdkHomeUrl `
    -Method        Get `
    -Headers       $headers `
    -UseBasicParsing

if (-not $homeHtml) {
    throw "Failed to retrieve HTML from '$($openJdkHomeUrl)'"
}

# Resolve the latest JDK downloads page link from the home page.
#
# Example match:
#   https://jdk.java.net/23
$latestPagePattern = 'https:\/\/jdk\.java\.net\/\d+'
$latestJdkPageUrl = [regex]::Match([string]$homeHtml.Content, $latestPagePattern).Value

if ([string]::IsNullOrWhiteSpace($latestJdkPageUrl)) {
    throw "Could not find a latest JDK page link using pattern: '$($latestPagePattern)'"
}

Write-Host "Resolved latest JDK page: $($latestJdkPageUrl)" -ForegroundColor DarkGray

# Retrieve the latest JDK downloads page HTML.
Write-Host "Retrieving latest JDK downloads page: $($latestJdkPageUrl)" -ForegroundColor DarkGray

$latestPageHtml = Invoke-WebRequest `
    -Uri           $latestJdkPageUrl `
    -Method        Get `
    -Headers       $headers `
    -UseBasicParsing

if (-not $latestPageHtml) {
    throw "Failed to retrieve HTML from '$($latestJdkPageUrl)'"
}

# Extract the platform-specific x64 binary download link from the latest page HTML.
#
# Notes:
#   - Matches x64 binary assets for the selected OS
#   - Excludes checksum links (sha files)
$assetPattern = ('(?<=")https:.*?' + $os + '-x64_bin(?!.*\.sha).*?(?=")')
$downloadUrl = [regex]::Match([string]$latestPageHtml.Content, $assetPattern).Value

if (-not $downloadUrl) {
    throw "No x64_bin links found on '$($latestJdkPageUrl)' using pattern: '$($assetPattern)'"
}

Write-Host "Resolved OpenJDK download URL: $($downloadUrl)" -ForegroundColor DarkGray

# Download the resolved archive into the archive directory.
#
# Notes:
#   - The file name is derived from the URL
#   - A fallback file name is used if URL parsing does not produce a file name
$fileName = [System.IO.Path]::GetFileName([Uri]$downloadUrl)
if ([string]::IsNullOrWhiteSpace($fileName)) {
    $fileName = "download-$([Guid]::NewGuid().ToString('N')).bin"
}

$outFile = Join-Path -Path $ArchiveDirectory -ChildPath $fileName

Write-Host "Downloading OpenJDK archive to: '$($outFile)'" -ForegroundColor DarkGray

try {
    Invoke-WebRequest `
        -Uri     $downloadUrl `
        -Method  Get `
        -OutFile $outFile `
        -Headers $headers `
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
# -Force ensures existing files are overwritten if present.
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
#   - Many JDK archives extract into a single top-level directory
#   - This function moves all contents up one level to place the JDK files
#     directly under the destination directory
$jdkDirectory = Get-ChildItem -Path $DestinationDirectory -Directory |
Sort-Object Name |
Select-Object -First 1

if (-not $jdkDirectory) {
    Write-Warning "No extracted JDK directory was found in '$($DestinationDirectory)'"
    return
}

Write-Host "Flattening extracted layout by moving contents from '$($jdkDirectory.FullName)' to '$($DestinationDirectory)'"  -ForegroundColor DarkGray

# Move all extracted contents (files + folders) up one level.
Get-ChildItem -Path $jdkDirectory.FullName -Force | Move-Item -Destination $DestinationDirectory -Force

# Remove the now-empty top-level extracted directory.
$ProgressPreference = 'SilentlyContinue'
Remove-Item -Path $jdkDirectory.FullName -Force
$ProgressPreference = 'Continue'

Write-Host "OpenJDK installation completed. Destination directory: '$($DestinationDirectory)'"  -ForegroundColor Cyan

