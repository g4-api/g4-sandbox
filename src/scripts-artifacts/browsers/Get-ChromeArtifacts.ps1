<#
.SYNOPSIS
    Downloads Google "Chrome for Testing" artifacts (Chrome + ChromeDriver).

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.
    Downloads Chrome and ChromeDriver for a selected operating system and
    extracts them into flat destination directories for easy consumption by
    automation pipelines.

    - Optionally cleans the Chrome and Driver destination directories
    - Retrieves version metadata from the official Chrome for Testing endpoints
        * If -Version is provided: uses "known-good-versions-with-downloads.json"
          and selects a match by prefix (e.g. "113" matches "113.x.y.z")
        * If -Version is not provided: uses "last-known-good-versions-with-downloads.json"
          and selects the stable channel
    - Resolves platform-specific download URLs for Chrome and ChromeDriver
    - Downloads the archives into an archive directory
    - Extracts the archives into destination directories
    - Flattens the extracted folder structure (moves inner contents up one level)
    - Removes "*.chromedriver" license files under the destination directories

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)

.ASSUMPTIONS
    - Network access to googlechromelabs.github.io is available
    - Archive extraction tools are available:
        * Windows .zip: Expand-Archive (built-in)
        * Linux/macOS (and many Windows builds): tar must be available on PATH
#>
[CmdletBinding()]
param (
    # Chrome / ChromeDriver version selector.
    #
    # Notes:
    #   - When provided, the function will try to match by prefix against the full
    #     version string (e.g., "113" matches "113.0.5672.63").
    #   - If multiple matches exist, selection behavior depends on the selection logic
    #     in the metadata query (currently uses Select-Object -Last 1).
    [string]$Version,

    # Operating system selector used when matching Chrome for Testing platform values.
    #
    # Notes:
    #   - Values are normalized internally to the platform identifiers used by the
    #     Chrome for Testing metadata:
    #       * Windows -> win64
    #       * MacOs   -> mac-x64
    #       * Linux   -> linux64
    [ValidateSet("Linux", "MacOs", "Windows")]
    [string]$OperatingSystem,

    # Directory used to store the downloaded archive files.
    [string]$ArchiveDirectory,

    # Destination directory where the Chrome archive will be extracted.
    [string]$ChromeDestinationDirectory,

    # Destination directory where the ChromeDriver archive will be extracted.
    [string]$DriverDestinationDirectory,

    # When specified, removes destination directories before extraction.
    #
    # Behavior:
    #   - Removes the directory and all its contents
    #   - Only executed when -Clean is specified
    [Switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Clean the destination directories if explicitly requested.
#
# Behavior:
#   - Removes each destination directory and all its contents
#   - Only executed when -Clean is specified
foreach ($directory in @($ChromeDestinationDirectory, $DriverDestinationDirectory)) {
    if ($directory -and $Clean -and (Test-Path -Path $directory)) {

        Write-Host "Clean installation requested. Removing existing destination directory: '$($directory)'" -ForegroundColor DarkGray

        $ProgressPreference = 'SilentlyContinue'
        Remove-Item `
            -Path    $directory `
            -Recurse `
            -Force
        $ProgressPreference = 'Continue'
    }
}

# Ensure the archive directory exists.
# `-Force` creates the directory if it does not exist.
New-Item -Path $ArchiveDirectory -ItemType Directory -Force | Out-Null

# Ensure destination directories exist (they may have been removed by -Clean).
#
# Notes:
#   - Extraction requires the destination to exist
if ($ChromeDestinationDirectory) { 
    New-Item `
        -Path $ChromeDestinationDirectory `
        -ItemType Directory `
        -Force `
    | Out-Null
}

if ($DriverDestinationDirectory) { 
    New-Item `
        -Path $DriverDestinationDirectory `
        -ItemType Directory `
        -Force `
    | Out-Null
}

# Define HTTP headers.
#
# Notes:
#   - A User-Agent header reduces the likelihood of being blocked by upstream servers
#   - This is an unauthenticated request
$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
}

# Choose the appropriate Chrome for Testing metadata endpoint.
#
# Notes:
#   - If -Version is provided: use known-good versions list (many versions)
#   - If -Version is not provided: use last-known-good versions (stable/beta/dev, etc.)
$releasesIndexUrl = if ($Version) {
    "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json"
}
else {
    "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json"
}

# Normalize the operating system identifier to match Chrome for Testing platform values.
$os = [string]::Empty
switch ($OperatingSystem.ToLower()) {
    "macos" { $os = "mac-x64" }
    "linux" { $os = "linux64" }
    default { $os = "win64" }
}

Write-Host "Retrieving Chrome for Testing metadata: $($releasesIndexUrl)" -ForegroundColor DarkGray

$response = Invoke-WebRequest `
    -Uri            $releasesIndexUrl `
    -Headers        $headers `
    -Method         Get `
    -UseBasicParsing

if (-not $response -or $response.StatusCode -ge 400) {
    Write-Warning "Failed to retrieve Chrome for Testing metadata from: $($releasesIndexUrl)"
    return
}

# Parse the metadata JSON response.
$responseJson = $response.Content | ConvertFrom-Json

# Resolve the metadata entry to use.
#
# Notes:
#   - With -Version: we search the versions list and select a match
#   - Without -Version: we use the stable channel record
$metadata = if ($Version) {

    # Notes:
    #   - Matches by prefix, so "113" will match "113.0.5672.63"
    #   - Current selection uses Select-Object -Last 1
    $responseJson.versions | Where-Object { [Regex]::IsMatch($_.version, "^$([Regex]::Escape($Version))") } | Select-Object -Last 1
}
else {
    $responseJson.channels.Stable
}

if (-not $metadata) {
    Write-Warning "No Chrome for Testing metadata entry was resolved (Version: '$($Version)')."
    return
}

# Validate that chromedriver downloads exist in the resolved metadata.
#
# Notes:
#   - Stable response should contain downloads.chrome and downloads.chromedriver
if (-not ($metadata.PSObject.Properties.Name -contains 'downloads')) {
    Write-Warning "Resolved metadata does not contain a 'downloads' property."
    return
}

if (-not ($metadata.downloads.PSObject.Properties.Name -contains 'chromedriver')) {
    Write-Warning "Resolved metadata does not contain ChromeDriver downloads."
    return
}

# Build a download plan for Chrome and ChromeDriver.
#
# Notes:
#   - Each plan entry includes a destination directory and a URL
#   - The first matching platform entry is selected for each artifact
$downloads = @(
    @{
        Name                 = "Chrome"
        DestinationDirectory = $ChromeDestinationDirectory
        Url                  = ($metadata.downloads.chrome | Where-Object { $_.platform -eq $os } | Select-Object -First 1).url
    },
    @{
        Name                 = "ChromeDriver"
        DestinationDirectory = $DriverDestinationDirectory
        Url                  = ($metadata.downloads.chromedriver | Where-Object { $_.platform -eq $os } | Select-Object -First 1).url
    }
)

# Download + extract each artifact.
foreach ($download in $downloads) {

    # Skip entries that are not configured (e.g., destination missing).
    #
    # Notes:
    #   - Keeps behavior forgiving when caller only wants one of the artifacts
    if (-not $download.DestinationDirectory) {
        Write-Host "Skipping $($download.Name) because DestinationDirectory was not provided." -ForegroundColor DarkGray
        continue
    }

    if ([string]::IsNullOrWhiteSpace($download.Url)) {
        Write-Warning "No download URL resolved for $($download.Name) ($($os))."
        return
    }

    try {
        # Determine output file name from URL.
        #
        # Notes:
        #   - A fallback file name is used if URL parsing fails for any reason
        $fileName = [System.IO.Path]::GetFileName([Uri]$download.Url)
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            $fileName = "download-$([Guid]::NewGuid().ToString('N')).bin"
        }

        $outFile = Join-Path -Path $ArchiveDirectory -ChildPath $fileName

        Write-Host "Downloading $($download.Name) archive to: '$($outFile)'" -ForegroundColor DarkGray

        Invoke-WebRequest `
            -Uri      $download.Url `
            -Method   Get `
            -OutFile  $outFile `
            -Headers  $headers `
            -UseBasicParsing

        Write-Host "Archive saved in: '$($ArchiveDirectory)'" -ForegroundColor DarkGray

        # Extract the archive into the destination directory.
        #
        # Notes:
        #   - .zip: Expand-Archive
        #   - .tar.gz / .tgz / .tar.xz: tar
        Write-Host "Extracting $($download.Name) archive '$($outFile)' into: '$($download.DestinationDirectory)'" -ForegroundColor Cyan

        $outFileLower = $outFile.ToLowerInvariant()

        if ($outFileLower.EndsWith(".zip")) {

            # -Force ensures existing files are overwritten if present.
            Expand-Archive `
                -Path            $outFile `
                -DestinationPath $download.DestinationDirectory `
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
            & tar -xf $outFile -C $download.DestinationDirectory
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
        #   - Chrome for Testing archives typically extract into a single top-level directory
        #     (e.g., "chrome-win64", "chromedriver-win64")
        #   - This step moves all inner contents up one level to place files directly
        #     under the destination directory
        $topLevelDirectory = Get-ChildItem -Path $download.DestinationDirectory -Directory | Sort-Object Name | Select-Object -First 1

        if (-not $topLevelDirectory) {
            Write-Warning "No extracted top-level directory was found in '$($download.DestinationDirectory)'"
            return
        }

        Write-Host "Flattening extracted layout by moving contents from '$($topLevelDirectory.FullName)' to '$($download.DestinationDirectory)'" -ForegroundColor DarkGray

        # Move all extracted contents (files + folders) up one level.
        Get-ChildItem -Path $topLevelDirectory.FullName -Force | Move-Item -Destination $download.DestinationDirectory -Force

        # Remove the now-empty top-level extracted directory.
        $ProgressPreference = 'SilentlyContinue'
        Remove-Item -Path $topLevelDirectory.FullName -Force
        $ProgressPreference = 'Continue'
        

        # Remove LICENSE files to keep the portable payload minimal.
        #
        # Notes:
        #   - Matches LICENSE, LICENSE.txt, LICENSE.chromedriver, etc.
        $ProgressPreference = 'SilentlyContinue'
        Get-ChildItem `
            -Path   $download.DestinationDirectory `
            -Filter "*.chromedriver" `
            -File `
            -Recurse | Remove-Item -Force
        $ProgressPreference = 'Continue'

        Write-Host "$($download.Name) installation completed. Destination directory: '$($download.DestinationDirectory)'" -ForegroundColor Cyan
    }
    catch {
        throw "Chrome artifact deployment failed for '$($download.Url)': $($_.Exception.Message)"
    }
}
