# ---------------------------------------------------------------------------
# Script: G4 Sandbox Builder
#
# Purpose:
#   Builds a fully portable G4 sandbox environment by downloading,
#   assembling, and staging all required runtimes, browsers, drivers,
#   utilities, and configuration assets.
#
# Description:
#   - Orchestrates the end-to-end sandbox build process
#   - Downloads platform-specific dependencies (Chrome, .NET, JDK, Node.js, etc.)
#   - Retrieves required G4 tools and utilities from GitHub releases
#   - Packages VS Code extensions for offline installation
#   - Copies local project assets (CLI, Docker, K8s, Grid configs)
#   - Produces a deterministic, portable output layout suitable for:
#       * Local execution
#       * CI/CD artifacts
#       * Container mounting
#       * Air-gapped environments
#
# Compatibility:
#   - PowerShell 5.x (Windows)
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Network access to required upstream endpoints is available
#   - Helper functions (Get-*, Resolve-*) are loaded in scope
#   - Output directory is writable
#   - tar is available on PATH for non-zip extractions when required
# ---------------------------------------------------------------------------
[CmdletBinding()]
param(
    # Root volume/path where the bot will operate.
    #
    # Notes:
    #   - Typically mounted into containers or used as the runtime working directory
    #   - Caller is responsible for ensuring sufficient disk space
    [string]$BotVolume,
    
    # Chrome version to download.
    #
    # Notes:
    #   - Passed through to Chrome artifact resolver
    #   - Can be full version (e.g., 120.0.6099.71) or major prefix (e.g., 120)
    #   - When omitted in downstream calls, latest stable may be used
    [string]$ChormeVersion,
    
    # .NET major version selector.
    #
    # Notes:
    #   - Default is "10"
    #   - Consumed by Get-Dotnet to resolve the correct runtime channel
    [string]$DotnetVersion = "10",

    # G4 Hub base URI.
    #
    # Notes:
    #   - Used by bots/services to communicate with the hub
    #   - Should be reachable from the runtime environment
    [string]$HubUri = "http://localhost:9944",
    
    # Target operating system.
    #
    # Notes:
    #   - Drives platform-specific artifact selection across the pipeline
    #   - Must match supported ValidateSet values
    [ValidateSet("Linux", "MacOs", "Windows")]
    [string]$OperatingSystem = "Linux",
    
    # Output directory for the assembled sandbox/package.
    #
    # Notes:
    #   - Relative paths are resolved from the current working directory
    #   - Will typically contain the final staged G4 bundle
    [string]$OutputDirectory = "/tmp/g4-sandbox",
    
    # When specified, performs a clean rebuild.
    #
    # Behavior:
    #   - Downstream steps may remove existing directories
    #   - Ensures deterministic build output
    [switch]$Clean
)

# Enable strict mode for safer scripting.
#
# Notes:
#   - Latest enforces:
#       * No use of uninitialized variables
#       * No referencing non-existent properties
#       * Stricter function semantics
Set-StrictMode -Version Latest

# Fail fast on all non-terminating errors.
#
# Notes:
#   - Converts many recoverable errors into terminating ones
#   - Ensures CI/CD pipelines fail deterministically
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Function: Get-ChromeArtifacts
#
# Purpose:
#   Downloads Google "Chrome for Testing" artifacts (Chrome + ChromeDriver)
#   for a selected operating system and extracts them into flat destination
#   directories for easy consumption by automation pipelines.
#
# Description:
#   - Optionally cleans the Chrome and Driver destination directories
#   - Retrieves version metadata from the official Chrome for Testing endpoints
#       * If -Version is provided: uses "known-good-versions-with-downloads.json"
#         and selects a match by prefix (e.g. "113" matches "113.x.y.z")
#       * If -Version is not provided: uses "last-known-good-versions-with-downloads.json"
#         and selects the stable channel
#   - Resolves platform-specific download URLs for:
#       * Chrome (browser)
#       * ChromeDriver (driver)
#   - Downloads the archives into an archive directory
#   - Extracts the archives into destination directories
#   - Flattens the extracted folder structure (moves inner contents up one level)
#   - Removes "LICENSE*" files under the destination directories
#
# Compatibility:
#   - PowerShell 5.x (Windows)
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Network access to googlechromelabs.github.io is available
#   - The Chrome for Testing metadata endpoints remain stable:
#       https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json
#       https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json
#   - Archive extraction tools are available:
#       * Windows .zip: Expand-Archive (built-in)
#       * Linux/macOS (and many Windows builds): tar must be available on PATH for .tar.* archives
# ---------------------------------------------------------------------------
function Get-ChromeArtifacts {
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
            Write-Warning "Download or extraction failed for: $($download.Url)"
            Write-Warning $_.Exception.Message
            return
        }
    }
}

# ---------------------------------------------------------------------------
# Function: Get-Dotnet
#
# Purpose:
#   Downloads a .NET SDK archive for a specific major version and operating
#   system, and extracts it into a destination directory.
#
# Description:
#   - Optionally cleans the destination directory before installation
#   - Downloads the official .NET release index metadata (releases-index.json)
#   - Resolves the matching release channel for the requested major version
#   - Downloads the latest SDK archive for the selected operating system (x64)
#   - Extracts the archive into the destination directory
#
# Compatibility:
#   - PowerShell 5.x
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Network access to Microsoft .NET release metadata endpoints is available
#   - Archive extraction uses Expand-Archive, so the resolved asset must be a .zip
#   - The metadata format and channel naming conventions remain stable
# ---------------------------------------------------------------------------
function Get-Dotnet {
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
}

# ---------------------------------------------------------------------------
# Function: Get-G4Artifact
#
# Purpose:
#   Downloads a versioned G4 release artifact from a GitHub repository and
#   extracts it into a local destination directory.
#
# Description:
#   - Resolves the requested release (explicit tag or latest available)
#   - Uses the resolved release download URL (artifact) from GitHub
#   - Optionally cleans the destination directory before extraction
#   - Downloads the archive to a local file path
#   - Extracts the archive into the destination directory
#
# Compatibility:
#   - PowerShell 5.x
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - `$ArchiveFilePath` points to a writable file location
#   - The GitHub release and artifact naming convention is stable
#   - Network access to github.com is available
# ---------------------------------------------------------------------------
function Get-G4Artifact {
    [CmdletBinding()]
    param(
        # GitHub repository name under the g4-api organization.
        # Example: "g4-services"
        [string]$GitHubRepository,

        # Optional release tag.
        # If not provided, the latest release is resolved dynamically.
        # Example: "v1.4.2" or "1.4.2" (depends on your resolver behavior)
        [string]$Tag,

        # Optional pattern to select a specific asset from the release.
        # If not provided, the first asset in the release is used.
        # Example: "linux-x64.zip" to select a specific platform artifact
        [string]$AssetPattern,

        # Full directory where the downloaded archive will be saved.
        # Example: "/tmp"
        [string]$ArchiveDirectory,

        # Destination directory where the archive contents will be extracted.
        # Defaults to the repository name if not explicitly provided.
        [string]$DestinationDirectory,
        [string]$DestinationFile,

        # When specified, removes the destination directory before extraction.
        # This guarantees a clean, deterministic installation state.
        [switch]$Clean
    )

    # ---------------------------------------------------------------------------
    # Script block: Resolve-LatestVersion
    #
    # Purpose:
    #   Resolves GitHub release metadata (latest release or a specific tag) for a
    #   repository under the g4-api organization, and returns:
    #     - The resolved release tag
    #     - A resolved download URL for a release asset
    #
    # Description:
    #   This script block queries the public GitHub REST API and returns a small,
    #   structured result that can be used by download/install functions.
    #
    # Behavior:
    #   - Performs an unauthenticated HTTP GET request against the GitHub API
    #   - Uses either:
    #       - /releases/latest (when Tag is not provided)
    #       - /releases/tags/<tag> (when Tag is provided)
    #   - Reads the release tag_name from the API response
    #   - Selects a download URL from the release assets list
    #   - Returns an empty string if any step fails
    #
    # Notes:
    #   - Uses the public GitHub API (no token required)
    #   - Subject to unauthenticated rate limits (typically 60 requests/hour per IP)
    #   - GitHub requires a User-Agent header even for unauthenticated API calls
    #   - Release assets are returned as an array; a single URL must be selected
    #
    # Parameters:
    #   - GitHubRepository [string]
    #       The repository name under the g4-api GitHub organization.
    #       Example:
    #         "g4-services"
    #
    #   - Tag [string]
    #       Optional release tag to resolve.
    #       If not provided, the latest release is resolved.
    #       Example:
    #         "v1.2.3"
    #
    # Compatibility:
    #   - Designed to work with PowerShell 5.x
    #   - Compatible with PowerShell Core (Windows, Linux, macOS)
    #
    # Return Value:
    #   - On success:
    #       A hashtable with:
    #         - Tag         [string]  (example: "v1.2.3")
    #         - DownloadUrl [string]  (example: "https://github.com/.../download/...zip")
    #
    #   - On failure:
    #       [string]::Empty
    # ---------------------------------------------------------------------------
    $resolveLatestVersion = {
        param(
            [string]$GitHubRepository,
            [string]$Tag,
            [string]$AssetPattern
        )

        # Construct the GitHub API URL for resolving release information.
        #
        # When Tag is provided:
        #   /releases/tags/<tag>
        #
        # When Tag is not provided:
        #   /releases/latest
        $apiUrl = if ($Tag) {
            "$($GitHubRepository)/releases/tags/$($Tag)"
        }
        else {
            "$($GitHubRepository)/releases/latest"
        }

        # Define required HTTP headers.
        #
        # Notes:
        #   - GitHub requires a User-Agent header
        #   - Accept header requests the modern JSON media type
        $headers = @{
            "Accept"     = "application/vnd.github+json"
            "User-Agent" = "PowerShell/$($PSVersionTable.PSVersion)"
        }

        # Execute an HTTP GET request against the GitHub API.
        #
        # -UseBasicParsing ensures compatibility with PowerShell 5.x.
        # -ErrorAction Stop ensures we land in catch on any request failure.
        try {
            $response = Invoke-RestMethod `
                -Uri             $apiUrl `
                -Method          Get `
                -Headers         $headers `
                -UseBasicParsing `
                -ErrorAction     Stop
        }
        catch {
            Write-Warning "Failed to retrieve GitHub release information from: $($apiUrl)"
            return $null
        }

        # Extract the resolved release tag name from the API response.
        #
        # Common formats include:
        #   - v1.2.3
        #   - 1.2.3
        $tagName = $response.tag_name

        # Validate that a tag name was returned.
        if (-not $tagName) {
            Write-Warning "GitHub API response did not include a release tag (tag_name)."
            return $null
        }

        # Validate that the resolved release includes downloadable assets.
        #
        # Notes:
        #   - GitHub releases may exist without attached binary assets
        #   - Downstream download logic requires at least one release asset
        #   - An empty assets list is treated as a failure condition
        if (-not $response.assets -or $response.assets.Length -eq 0) {
            Write-Warning "GitHub release was resolved successfully, but no downloadable assets were found for this release."
            return $null
        }

        # Select the first asset as the default artifact.
        # This keeps the resolver generic and lightweight.
        if (-not $AssetPattern -or [string]::IsNullOrEmpty($AssetPattern)) {
            $asset = $response.assets[0]
            $downloadUrl = $asset.browser_download_url
        }
        else {
            $asset = $response.assets | Where-Object { [Regex]::IsMatch($_.name, $AssetPattern) } | Select-Object -First 1
            $downloadUrl = $asset.browser_download_url
        }

        # Validate that a download URL was found.
        #
        # If the release exists but includes no assets, we treat this as a failure
        # because the downstream download step cannot continue.
        if (-not $downloadUrl) {
            Write-Warning "Release '$($tagName)' was found, but no downloadable release assets were returned."
            return $null
        }

        # Return a small, structured result for downstream installers.
        return @{
            DownloadUrl = $downloadUrl
            FileName    = $asset.name
            Tag         = $tagName
        }
    }

    # Resolve the destination path.
    # Default to the repository name if no destination path was provided.
    $DestinationDirectory = if (-not $DestinationDirectory) {
        $GitHubRepository
    }
    else {
        $DestinationDirectory
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
            -Path $DestinationDirectory `
            -Recurse `
            -Force
        $ProgressPreference = 'Continue'
    }

    # Resolve the release metadata (latest or by tag).
    #
    # Notes:
    #   - The resolver is expected to return an object that includes DownloadUrl
    #   - This function does not build the artifact URL itself; it trusts the resolver
    $release = & $resolveLatestVersion `
        -AssetPattern     $AssetPattern `
        -GitHubRepository $GitHubRepository `
        -Tag              $Tag

    # Validate that release metadata was successfully resolved.
    #
    # Notes:
    #   - A missing or empty release object indicates a failure to resolve
    #     release information from GitHub
    #   - Execution cannot continue without a valid release definition
    if (-not $release) {
        Write-Error "Failed to resolve GitHub release information. Aborting artifact download."
        return
    }

    # Use the resolved GitHub download URL for the artifact.
    $downloadUrl = $release.DownloadUrl

    # Ensure the working directory exists.
    #
    # Notes:
    #   - `-Force` creates the directory if it does not exist
    #   - Output is suppressed intentionally
    New-Item -ItemType Directory -Path $workDirectory -Force | Out-Null

    # Download the archive from GitHub to the specified file path.
    #
    # UseBasicParsing:
    #   Ensures compatibility with PowerShell 5.x environments.
    $archiveFilePath = Join-Path $ArchiveDirectory $release.FileName
    Write-Host "Downloading release artifact from '$($downloadUrl)' to '$($archiveFilePath)'" -ForegroundColor DarkGray

    Invoke-WebRequest `
        -Uri     $downloadUrl `
        -OutFile $archiveFilePath `
        -UseBasicParsing

    # Supported archive extensions used to decide between "extract" vs "move".
    #
    # Notes:
    #   - Includes common zip + tar variants and compressed tar formats
    #   - This is a heuristic based on file name suffix
    $archiveExtensions = @(
        ".zip",
        ".tar",
        ".tar.gz",
        ".tgz",
        ".tar.bz2",
        ".tbz2",
        ".tar.xz",
        ".txz",
        ".gz",
        ".bz2",
        ".xz"
    )

    # Resolve the file name from the archive path and normalize it for comparisons.
    #
    # Notes:
    #   - Lower-casing ensures suffix checks are case-insensitive (e.g. .ZIP)
    $fileName = [System.IO.Path]::GetFileName($archiveFilePath).ToLower()

    # Determine whether the file looks like an archive based on its extension.
    #
    # Notes:
    #   - If any suffix matches, $isArchive will be a non-empty value
    #   - If no suffix matches, $isArchive will be $null / empty
    $isArchive = $archiveExtensions | Where-Object { $fileName.EndsWith($_) }

    # Resolve the output file name.
    #
    # Behavior:
    #   - If DestinationFile is provided, it overrides the resolved file name
    #   - Otherwise, we keep the original file name
    $fileName = if (-not $DestinationFile) { $fileName } else { $DestinationFile }

    # If the file is not an archive, move it directly to the destination directory.
    #
    # Notes:
    #   - This path is used for binaries or standalone files that should not be extracted
    if (-not $isArchive) {
        Write-Host "File is not an archive. Moving without extraction:" -ForegroundColor Gray
        Write-Host "  $($archiveFilePath) -> $($DestinationDirectory)" -ForegroundColor Gray

        # Ensure the destination directory exists before moving the file.
        [System.IO.Directory]::CreateDirectory($DestinationDirectory)

        # Move the file into the destination directory and overwrite if it already exists.
        Move-Item `
            -LiteralPath $archiveFilePath `
            -Destination (Join-Path $DestinationDirectory $fileName) `
            -Force
    }
    else {
        # Archive path: extract into the destination directory.
        Write-Host "Extracting archive:" -ForegroundColor Cyan
        Write-Host "  $($archiveFilePath) -> $($DestinationDirectory)" -ForegroundColor Cyan

        # Ensure the destination directory exists for extraction.
        New-Item `
            -Path     $DestinationDirectory `
            -ItemType Directory `
            -Force `
        | Out-Null

        # Extract ZIP archives using Expand-Archive.
        #
        # Notes:
        #   - Expand-Archive is built-in on Windows PowerShell and PowerShell Core
        #   - -Force overwrites existing files when present
        if ($archiveFilePath.EndsWith(".zip")) {
            Expand-Archive `
                -LiteralPath     $archiveFilePath `
                -DestinationPath $DestinationDirectory `
                -Force
        }
        elseif (
            $archiveFilePath.EndsWith(".tar.gz") -or
            $archiveFilePath.EndsWith(".tgz") -or
            $archiveFilePath.EndsWith(".tar.xz")
        ) {
            # Extract tar-based archives using 'tar'.
            #
            # Notes:
            #   - tar is available by default on most Linux/macOS distributions
            #   - On Windows PowerShell 5, tar may be available on newer Windows builds;
            #     if not, users should install a tar-capable tool or use the Windows zip variant.
            $tar = Get-Command tar -ErrorAction SilentlyContinue
            if (-not $tar) {
                Write-Warning "Cannot extract tar archive because 'tar' was not found on PATH. Archive: '$($archiveFilePath)'"
                return
            }

            # -x: extract, -f: file, -C: destination directory
            & tar -xf $archiveFilePath -C $DestinationDirectory
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "tar extraction failed for: '$($archiveFilePath)' (exit code: $($LASTEXITCODE))"
                return
            }
        }
        else {
            # Archive extension is recognized as "archive-like" by our heuristic,
            # but we do not support extraction for this particular format yet.
            Write-Warning "Unsupported archive format for: '$($archiveFilePath)'."
            return
        }
    }
}

# ---------------------------------------------------------------------------
# Function: Get-NodeJs
#
# Purpose:
#   Downloads a Node.js distribution archive for a selected operating system
#   and extracts it into a destination directory in a flat, easy-to-use layout.
#
# Description:
#   - Optionally cleans the destination directory before installation
#   - Retrieves Node.js release metadata from the official index.json endpoint
#   - Resolves the requested Node.js version (exact match), or falls back to latest
#   - Builds the platform-specific download URL for the selected OS/format
#   - Downloads the archive into an archive directory
#   - Extracts the archive into the destination directory
#   - Moves extracted contents up one level to avoid a nested "node-vX.Y.Z-<os>-x64" folder
#
# Compatibility:
#   - PowerShell 5.x (Windows)
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Network access to nodejs.org is available
#   - The Node.js dist index endpoint remains stable:
#       https://nodejs.org/dist/index.json
#   - Archive extraction tools are available:
#       * Windows .zip: Expand-Archive (built-in)
#       * Linux/macOS .tar.*: tar must be available on PATH
# ---------------------------------------------------------------------------
function Get-NodeJs {
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
}

# ---------------------------------------------------------------------------
# Function: Get-OpenJdkBinaries
#
# Purpose:
#   Downloads the latest OpenJDK binary archive for a selected operating system
#   and extracts it into a destination directory in a flat, easy-to-use layout.
#
# Description:
#   - Optionally cleans the destination directory before installation
#   - Retrieves the OpenJDK home page and resolves the latest JDK downloads page
#   - Extracts the platform-specific x64 binary download URL from the page
#   - Downloads the archive into an archive directory
#   - Extracts the archive into the destination directory
#   - Moves extracted contents up one level to avoid a nested JDK folder layout
#
# Compatibility:
#   - PowerShell 5.x
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Network access to openjdk.org and jdk.java.net is available
#   - The OpenJDK site structure and link patterns remain stable
#   - The selected archive format is supported by Expand-Archive
# ---------------------------------------------------------------------------
function Get-OpenJdkBinaries {
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
}

# ---------------------------------------------------------------------------
# Function: Get-PowershellCore
#
# Purpose:
#   Downloads the latest PowerShell Core portable distribution for the
#   selected operating system and extracts it into the destination directory.
#
# Description:
#   - Resolves the correct platform asset from the PowerShell GitHub releases
#   - Filters the release asset using a platform-specific regex pattern
#   - Downloads the archive into the archive directory
#   - Extracts the archive into the destination directory
#   - Optionally renames the downloaded archive file
#
# Compatibility:
#   - PowerShell 5.x (Windows)
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Network access to api.github.com is available
#   - PowerShell GitHub releases structure remains stable
#   - Archive extraction tools are available on the host system
# ---------------------------------------------------------------------------
function Get-PowershellCore {
    [CmdletBinding()]
    param(
        # Operating system selector.
        #
        # Notes:
        #   - Determines which PowerShell portable asset will be selected
        #   - Mapped internally to GitHub release naming conventions
        [ValidateSet("Linux", "MacOs", "Windows")]
        [string]$OperatingSystem,
        
        # Destination directory where PowerShell will be extracted.
        #
        # Notes:
        #   - Should be a portable/runtime location (e.g., runtime/powershell)
        [string]$DestinationDirectory,

        # Optional destination file name for the downloaded archive.
        #
        # Notes:
        #   - When provided, overrides the original GitHub asset file name
        [string]$DestinationFile,

        # Directory used to store downloaded archives.
        #
        # Notes:
        #   - Acts as the working/cache directory for downloads
        [string]$ArchiveDirectory
    )

    # Normalize OS and resolve the expected GitHub asset pattern.
    #
    # Notes:
    #   - PowerShell releases use platform-specific naming
    #   - Regex pattern is used later by Get-G4Artifact to pick the correct asset
    switch ($OperatingSystem.ToLower()) {
        "macos" {
            $assertPattern = "osx-x64\.tar\.gz$"
        }
        "linux" {
            $assertPattern = "linux-x64\.tar\.gz$"
        }
        default {
            $assertPattern = "win-x64\.zip$"
        }
    }

    # Download and extract the PowerShell release artifact.
    #
    # Behavior:
    #   - Queries the PowerShell GitHub releases API
    #   - Filters the correct asset using $assertPattern
    #   - Downloads into $ArchiveDirectory
    #   - Extracts into $DestinationDirectory
    #
    # Notes:
    #   - Get-G4Artifact encapsulates the full GitHub release handling logic
    #   - This function acts as a thin platform-aware wrapper
    Get-G4Artifact `
        -ArchiveDirectory     $ArchiveDirectory `
        -AssetPattern         $assertPattern `
        -DestinationDirectory $DestinationDirectory `
        -DestinationFile      $DestinationFile `
        -GitHubRepository     "https://api.github.com/repos/PowerShell/PowerShell"
    
    # Skip permission changes on Windows.
    #
    # Notes:
    #   - Windows does not use POSIX execute permissions
    #   - chmod is not applicable on Windows hosts
    if ($OperatingSystem -eq "Windows") {
        return
    }

    # Resolve the expected PowerShell binary path.
    #
    # Notes:
    #   - Portable PowerShell extracts the executable as "pwsh" on Linux/macOS
    #   - This must exist before we attempt to set execute permissions
    $pwshPath = Join-Path -Path $DestinationDirectory -ChildPath "pwsh"

    # Validate that the PowerShell binary exists.
    #
    # Behavior:
    #   - Warn and exit early if extraction did not produce the expected file
    if (-not (Test-Path -Path $pwshPath)) {
        Write-Warning "Expected PowerShell executable not found at: '$($pwshPath)'"
        return
    }

    # Ensure the PowerShell binary is executable.
    #
    # Notes:
    #   - Required on Linux/macOS for portable distributions
    #   - +x adds execute permission for user/group/others
    Write-Host "Setting execute permissions on PowerShell binary: '$($pwshPath)'" -ForegroundColor DarkGray
    chmod +x $pwshPath
}

# ---------------------------------------------------------------------------
# Function: Get-VSCode
#
# Purpose:
#   Downloads a Visual Studio Code distribution archive for a selected operating
#   system (x64 only) and extracts it into a destination directory in a flat,
#   easy-to-use layout.
#
# Description:
#   - Optionally cleans the destination directory before installation
#   - Retrieves VS Code release versions from the official update API
#   - Resolves the requested VS Code version (exact match), or falls back to latest
#   - Builds the platform-specific download URL for the selected OS (x64 only)
#   - Downloads the archive into an archive directory
#   - Extracts the archive into a staging directory
#   - Moves extracted contents up one level to avoid a nested top-level folder
#
# Compatibility:
#   - PowerShell 5.x (Windows)
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Network access to update.code.visualstudio.com is available
#   - VS Code update endpoints remain stable:
#       * Releases list: https://update.code.visualstudio.com/api/releases/stable
#       * Download:      https://update.code.visualstudio.com/<version>/<platform>/stable
#   - Archive extraction tools are available:
#       * Windows .zip: Expand-Archive (built-in)
#       * Linux/macOS .tar.gz: tar must be available on PATH
# ---------------------------------------------------------------------------
function Get-VSCode {
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
}

# ---------------------------------------------------------------------------
# Function: Get-VSCodeVsix
#
# Purpose:
#   Downloads a VS Code extension VSIX from the Visual Studio Marketplace.
#   If -Version is not provided, selects the latest available version.
#   Recursively downloads the entire dependency tree (ExtensionDependencies + ExtensionPack).
#
# Description:
#   - Validates plugin identity format: 'publisher.extension' (example: ms-python.autopep8)
#   - Queries the Marketplace gallery extensionquery API to resolve versions + metadata
#   - Selects either:
#       * The latest version (when -Version is omitted), or
#       * The explicit version provided by the caller
#   - Downloads the VSIX package using the Marketplace vspackage endpoint
#   - Detects dependencies for the selected version and recursively downloads each
#   - Uses a visited list (-IgnoredDependencies) to prevent cycles and duplicate work
#
# Compatibility:
#   - PowerShell 5.x
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Network access to marketplace.visualstudio.com is available
#   - The Visual Studio Marketplace gallery APIs remain available and stable
#   - Invoke-RestMethod / Invoke-WebRequest can reach the endpoints (proxy/firewall permitting)
# ---------------------------------------------------------------------------
function Get-VSCodeVsix {
    param(
        # VS Code extension identifier in the format: 'publisher.extension'
        # Example: ms-python.autopep8
        [Parameter(Mandatory = $true)]
        [string]  $Plugin,

        # Cycle protection / visited set.
        # Internal callers pass this through recursion to avoid repeated downloads.
        [string[]]$IgnoredDependencies,

        # Optional explicit extension version (e.g. "0.3.0").
        # If omitted, the latest version returned by the Marketplace is selected.
        [string]  $Version,

        # Destination directory where VSIX files will be saved.
        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory,

        # When specified, removes the destination directory before downloads.
        # This guarantees a clean, deterministic destination state.
        [Switch]$Clean
    )

    $Plugin = $Plugin.Trim().ToLowerInvariant()

    Write-Host "Processing VSIX: '$($Plugin)'" -ForegroundColor Cyan

    # Enforce plugin identity format.
    $publisher, $extensionName = $Plugin.Split('.', 2)
    if ([string]::IsNullOrWhiteSpace($publisher) -or [string]::IsNullOrWhiteSpace($extensionName)) {
        throw "Plugin format must be 'publisher.extension' (example: ms-python.autopep8)"
    }

    # Ensure we always have an array for cycle protection.
    if (-not $IgnoredDependencies) {
        $IgnoredDependencies = @()
    }

    # Stop recursion if already processed.
    #
    # Behavior:
    #   - Prevents infinite loops on circular dependencies
    #   - Avoids re-downloading the same extension multiple times
    if ($IgnoredDependencies -contains $Plugin) {
        Write-Host "Skipping already processed plugin (cycle protection): '$($Plugin)'" -ForegroundColor DarkGray
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

    # Ensure destination directory exists.
    # `-Force` creates the directory if it does not exist.
    New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null

    # Visual Studio Marketplace gallery API endpoint used to query extension metadata and versions.
    #
    # Notes:
    #   - This is NOT a simple GET endpoint; it expects a POST payload with filter criteria
    #   - The response includes extensions, versions, and per-version properties
    $queryUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=3.0-preview.1"

    Write-Host "Querying Marketplace metadata: '$($Plugin)'" -ForegroundColor DarkGray
    Write-Host "Gallery endpoint: $($queryUrl)"              -ForegroundColor DarkGray

    # Headers required by the gallery API (VS Code style)
    #
    # Notes:
    #   - Accept header helps ensure JSON response
    #   - Accept-Encoding gzip improves download efficiency
    $headers = @{
        "Accept"          = "application/json;api-version=3.0-preview.1"
        "Accept-Encoding" = "gzip"
        "User-Agent"      = "PowerShell"
    }

    # Query body:
    #
    # Notes:
    #   - filterType=8 targets VS Code extensions
    #   - filterType=7 is the extension name filter; in practice this often works with "publisher.extension"
    #   - flags controls which metadata is returned (versions, files, properties, etc.)
    $body = @{
        filters    = @(
            @{
                criteria   = @(
                    @{ filterType = 8; value = "Microsoft.VisualStudio.Code" } # Target product: VS Code
                    @{ filterType = 7; value = $Plugin }                      # Extension identifier
                )
                pageNumber = 1
                pageSize   = 50
                sortBy     = 0
                sortOrder  = 0
            }
        )
        assetTypes = @()
        flags      = 0x192
    } | ConvertTo-Json -Depth 20 -Compress

    try {
        $response = Invoke-RestMethod `
            -Method      Post `
            -Uri         $queryUrl `
            -Headers     $headers `
            -ContentType "application/json" `
            -Body        $body `
            -ErrorAction Stop
    }
    catch {
        throw "Failed to query Marketplace for '$($Plugin)'. $($_.Exception.Message)"
    }

    # Extract the first matching extension record.
    $extension = $response.results[0].extensions | Select-Object -First 1
    if (-not $extension) {
        Write-Warning "Extension not found: '$($Plugin)'."
        return
    }

    # Extract all version strings returned by the Marketplace response.
    #
    # Notes:
    #   - The gallery API returns a "versions" array with rich objects
    #   - Here we project it down to just the version string (e.g. "1.2.3")
    $versions = @(
        $extension.versions | ForEach-Object { $_.version }
    ) | Where-Object { $_ }

    # Fail fast if Marketplace did not return any versions.
    if ($versions.Length -eq 0) {
        throw "No versions returned for '$($Plugin)'."
    }

    Write-Host "Versions returned: $($versions.Length)" -ForegroundColor DarkGray

    # Pre-format versions as JSON for readable error messages.
    # This avoids dumping PowerShell array formatting into the exception text.
    $versionsJson = ($versions | ConvertTo-Json -Compress)

    # Select the version to download.
    #
    # Behavior:
    #   - If -Version is not provided => pick the latest version by semantic sorting
    #   - If -Version is provided     => validate it exists, then use it as-is
    #
    # Notes:
    #   - Casting to [version] enables correct numeric ordering (e.g. 2.10 > 2.9)
    #   - If a version string is not parseable as [version], sorting will throw
    $selectedVersion =
    if ([string]::IsNullOrWhiteSpace($Version)) {

        Write-Host "No version provided. Resolving latest available version..." -ForegroundColor DarkGray

        $latest = $versions `
        | Sort-Object { [version]$_ } -Descending `
        | Select-Object -First 1

        if ([string]::IsNullOrWhiteSpace($latest)) {
            throw "Failed to resolve latest version for '$($Plugin)'. Available: $($versionsJson)"
        }

        Write-Host "Selected latest version: $($latest)" -ForegroundColor Cyan
        $latest
    }
    else {

        Write-Host "Explicit version requested: $($Version)" -ForegroundColor DarkGray

        if ($versions -notcontains $Version) {
            throw "Version '$($Version)' not found for '$($Plugin)'. Available: $($versionsJson)"
        }

        Write-Host "Selected explicit version: $($Version)" -ForegroundColor Cyan
        $Version
    }

    # Locate the selected version object (needed for dependency metadata).
    $selectedVersionObject = $extension.versions `
    | Where-Object { $_.version -eq $selectedVersion } `
    | Select-Object -First 1

    if (-not $selectedVersionObject) {
        throw "Selected version metadata not found for '$($Plugin)' version '$($selectedVersion)'."
    }

    # Marketplace download endpoint (vspackage) is based on:
    #   /_apis/public/gallery/publishers/{publisher}/vsextensions/{extensionName}/{version}/vspackage
    $marketplaceUrl = "https://marketplace.visualstudio.com"
    $route = "_apis/public/gallery/publishers/$($publisher)/vsextensions/$($extensionName)/$($selectedVersion)/vspackage"
    $downloadUrl = "$($marketplaceUrl)/$($route)"

    # Output filename includes explicit version for deterministic caching.
    $outFile = Join-Path $DestinationDirectory "$($Plugin).$($selectedVersion).vsix"

    Write-Host "Downloading VSIX..." -ForegroundColor DarkGray
    Write-Host "  URL : $($downloadUrl)" -ForegroundColor DarkGray
    Write-Host "  OUT : $($outFile)" -ForegroundColor DarkGray

    # If file already exists, skip download.
    #
    # Notes:
    #   - Helps when rerunning the function on the same destination folder
    #   - Keeps recursion fast when dependencies were already fetched
    if (Test-Path -Path $outFile) {
        Write-Host "VSIX already exists. Skipping download: '$($outFile)'" -ForegroundColor DarkGray
    }
    else {
        try {
            Invoke-WebRequest `
                -Uri           $downloadUrl `
                -OutFile       $outFile `
                -ErrorAction   Stop `
                -UseBasicParsing
        }
        catch {
            if (Test-Path $outFile) {
                $ProgressPreference = 'SilentlyContinue'
                Remove-Item $outFile -Force -ErrorAction SilentlyContinue
                $ProgressPreference = 'Continue'
            }

            throw "Failed to download VSIX for '$($Plugin)' version '$($selectedVersion)'. $($_.Exception.Message)"
        }

        Write-Host "VSIX downloaded successfully: '$($outFile)'" -ForegroundColor Cyan
    }

    # Mark as visited (cycle protection) *after* successful selection/download attempt.
    $IgnoredDependencies = @($IgnoredDependencies + $Plugin)

    # The Marketplace returns dependency metadata as properties on the version object.
    #
    # Notes:
    #   - ExtensionDependencies: hard dependencies required by VS Code
    #   - ExtensionPack: a "meta extension" that lists other extensions to install together
    $dependenciesObject = $selectedVersionObject.properties `
    | Where-Object { $_.key -eq "Microsoft.VisualStudio.Code.ExtensionDependencies" } `
    | Select-Object -First 1

    $extensionPackObject = $selectedVersionObject.properties `
    | Where-Object { $_.key -eq "Microsoft.VisualStudio.Code.ExtensionPack" } `
    | Select-Object -First 1

    $dependencies = @()

    if ($dependenciesObject -and $dependenciesObject.value) {
        Write-Host "Found ExtensionDependencies for '$($Plugin)'." -ForegroundColor DarkGray
        $dependencies += $dependenciesObject.value.Split(',', [StringSplitOptions]::RemoveEmptyEntries)
    }

    if ($extensionPackObject -and $extensionPackObject.value) {
        Write-Host "Found ExtensionPack for '$($Plugin)'." -ForegroundColor DarkGray
        $dependencies += $extensionPackObject.value.Split(',', [StringSplitOptions]::RemoveEmptyEntries)
    }

    # Normalize dependency list.
    $dependencies = $dependencies `
    | ForEach-Object { $_.Trim().ToLowerInvariant() } `
    | Where-Object { $_ -and ($_ -notin $IgnoredDependencies) } `
    | Select-Object -Unique

    if (-not $dependencies -or ($dependencies.Length -eq 0)) {
        Write-Host "No new dependencies to process for '$($Plugin)'." -ForegroundColor DarkGray
        return
    }

    Write-Host "Dependencies to download for '$($Plugin)': $($dependencies.Length)" -ForegroundColor Cyan
    foreach ($d in $dependencies) {
        Write-Host "  - $($d)" -ForegroundColor DarkGray
    }

    # Recursively process each dependency.
    #
    # Behavior:
    #   - Each dependency is treated as a first-class VS Code extension
    #   - The same resolution, version selection, and download logic applies
    #   - The shared -IgnoredDependencies list prevents cycles and reprocessing
    #
    # Notes:
    #   - Recursion depth is typically shallow, but extension packs may expand
    #     into multiple layers of dependencies
    foreach ($dependency in $dependencies) {

        Write-Host "Recursing into dependency: '$($dependency)'" -ForegroundColor DarkGray

        Get-VSCodeVsix `
            -Plugin               $dependency `
            -IgnoredDependencies  $IgnoredDependencies `
            -DestinationDirectory $DestinationDirectory
    }
}

# ---------------------------------------------------------------------------
# Function: Resolve-G4ArtifactLatestVersion
#
# Purpose:
#   Resolves the latest release tag from a GitHub repository using the
#   GitHub Releases API.
#
# Description:
#   - Calls the GitHub "releases/latest" endpoint
#   - Validates the response structure
#   - Returns the resolved tag name (e.g., v1.2.3)
#   - Warns when no assets are present
#
# Compatibility:
#   - PowerShell 5.x
#   - PowerShell Core
#
# Assumptions:
#   - Repository exposes GitHub Releases
#   - Network access to api.github.com is available
# ---------------------------------------------------------------------------
function Resolve-G4ArtifactLatestVersion {
    param(
        # GitHub repository API base URL.
        #
        # Example:
        #   https://api.github.com/repos/org/repo
        #
        # Notes:
        #   - Function will append "/releases/latest"
        [string]$GitHubRepository
    )

    # Build the GitHub latest release endpoint.
    #
    # Example result:
    #   https://api.github.com/repos/org/repo/releases/latest
    $apiUrl = "$($GitHubRepository)/releases/latest"

    # Define HTTP headers for GitHub API compliance.
    #
    # Notes:
    #   - Accept header requests the modern GitHub JSON media type
    #   - User-Agent is required by GitHub API (requests may be rejected without it)
    $headers = @{
        "Accept"     = "application/vnd.github+json"
        "User-Agent" = "PowerShell/$($PSVersionTable.PSVersion)"
    }

    # Execute an HTTP GET request against the GitHub API.
    #
    # Notes:
    #   - -UseBasicParsing ensures compatibility with PowerShell 5.x
    #   - -ErrorAction Stop ensures we enter catch on any request failure
    try {
        $response = Invoke-RestMethod `
            -Uri         $apiUrl `
            -Method      Get `
            -Headers     $headers `
            -UseBasicParsing `
            -ErrorAction Stop
    }
    catch {
        # Network failure, rate limit, repo not found, etc.
        Write-Warning "Failed to retrieve GitHub release information from: $($apiUrl)"
        return $null
    }

    # Extract the resolved release tag name from the API response.
    #
    # Common formats:
    #   - v1.2.3
    #   - 1.2.3
    $tagName = $response.tag_name

    # Validate that a tag name was returned.
    if (-not $tagName) {
        Write-Warning "GitHub API response did not include a release tag (tag_name)."
        return $null
    }

    # Warn if the release contains no assets.
    #
    # Notes:
    #   - Some repositories publish tag-only releases
    #   - Caller may still choose to proceed depending on workflow
    if (-not $response.assets -or $response.assets.Length -eq 0) {
        Write-Warning "GitHub release was resolved successfully, but no downloadable assets were found for this release."
    }

    # Return the resolved tag name to the caller.
    return $tagName
}

# Resolve the base working directory for the staged G4 bundle.
#
# Notes:
#   - Navigates two levels up from the current script root
#   - All build/stage artifacts will be placed under "_g4"
$baseDirecotry = [System.IO.Path]::Combine($PSScriptRoot, "..", "..", "_g4")

# Base GitHub API URL for all g4-api repositories.
#
# Notes:
#   - TrimEnd ensures no double slash when appending repository names
$baseGithubUrl = "https://api.github.com/repos/g4-api".TrimEnd("/")

# Resolve the latest release tag for the g4-services repository.
#
# Notes:
#   - Returns values like: v1.2.3 or 1.2.3
#   - Used to version the sandbox output folder
#   - May return $null if the GitHub call fails
$sandboxVersion = Resolve-G4ArtifactLatestVersion `
    -GitHubRepository "$($baseGithubUrl)/g4-services"

# Build the versioned sandbox output directory.
#
# Example result:
#   <OutputDirectory>\g4-sandbox-v1.2.3
#
# Notes:
#   - Embeds the resolved version into the folder name
#   - Caller should ensure $sandboxVersion is not null if strict behavior is required
$sandboxDirectory = Join-Path "$($OutputDirectory)" "g4-sandbox-$($sandboxVersion)"

# Source directory (current script location).
#
# Notes:
#   - Used for copying local assets (docker, k8s, cli, etc.)
$sourceDirectory = [System.IO.Path]::Combine($PSScriptRoot)

# Staging and working directories.
#
# Notes:
#   - "a" acts as the final assembled stage
#   - "_work" stores temporary archives during download/extraction
$stageDirectory = Join-Path $baseDirecotry "a"
$workDirectory = Join-Path $baseDirecotry "_work"

# Structured stage subdirectories.
#
# Notes:
#   - Browsers: Chrome binaries
#   - Drivers: WebDriver binaries
#   - runtime: dotnet/jdk/nodejs
#   - utilities: supporting tools (VS Code, trackers, etc.)
$browsersDirectory = Join-Path $stageDirectory "browsers"
$driversDirectory = Join-Path $stageDirectory "drivers"
$runtimeDirectory = Join-Path $stageDirectory "runtime"
$utilitiesDirectory = Join-Path $stageDirectory "bot-utilities"

# Tool definitions to download from GitHub releases.
#
# Notes:
#   - AssetPattern: Regex to match release asset
#   - DestinationDirectory: Where artifact will be extracted/copied
#   - DestinationFile: Optional rename of downloaded asset
#   - GitHubRepository: GitHub API endpoint for releases
#   - WindowsOnly: Skip tool when not running on Windows
$tools = @(
    @{
        AssetPattern         = $null
        DestinationDirectory = (Join-Path $utilitiesDirectory "cursor-coordinate-tracker-win-x64")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/cursor-coordinate-tracker"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = $null
        DestinationDirectory = (Join-Path $stageDirectory "g4-hub")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/g4-services"
        WindowsOnly          = $false
    },
    @{
        AssetPattern         = "selenium-server-.*\.jar"
        DestinationDirectory = (Join-Path $stageDirectory "selenium-grid")
        DestinationFile      = "selenium-server.jar"
        GitHubRepository     = "https://api.github.com/repos/SeleniumHQ/selenium"
        WindowsOnly          = $false
    },
    @{
        AssetPattern         = $null
        DestinationDirectory = (Join-Path $utilitiesDirectory "simple-encryptor-decryptor")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/simple-encryptor-decryptor"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = "Uia\.DriverServer.*-emgu\.zip"
        DestinationDirectory = [System.IO.Path]::Combine($driversDirectory, "uia-driver-server")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/uia-driver-server"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = "AccessibilityInsightsPortable.*\.zip"
        DestinationDirectory = (Join-Path $utilitiesDirectory "accessibility-insights-win-x64")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/uia-driver-server"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = $null
        DestinationDirectory = (Join-Path $utilitiesDirectory "uia-peek-win-x64")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/uia-peek"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = $null
        DestinationDirectory = (Join-Path $utilitiesDirectory "uia-xpath-tester-win-x64")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/uia-xpath-tester"
        WindowsOnly          = $true
    }
)

# VS Code extensions to pre-download as VSIX packages.
#
# Notes:
#   - These are stored offline under bot-utilities/vsixs
#   - Enables fully portable/offline dev environments
$vscodeExtensions = @(
    "g4-api.g4-engine-client",
    "github.copilot-chat",
    "ms-python.autopep8",
    "ms-python.black-formatter",
    "ms-python.debugpy",
    "ms-python.flake8",
    "ms-python.isort",
    "ms-python.pylint",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "ms-python.vscode-python-envs",
    "ms-vscode.powershell",
    "ms-vscode-remote.remote-wsl",
    "sonarsource.sonarlint-vscode"
)

# Download Chrome + ChromeDriver.
#
# Notes:
#   - Artifacts are stored under browsers/<os>/chrome and drivers/<os>/chrome
#   - -Clean ensures deterministic rebuilds
Get-ChromeArtifacts `
    -OperatingSystem            $OperatingSystem `
    -ArchiveDirectory           $workDirectory `
    -ChromeDestinationDirectory ([System.IO.Path]::Combine($browsersDirectory, "chrome")) `
    -DriverDestinationDirectory ([System.IO.Path]::Combine($driversDirectory, "chrome")) `
    -Clean

# Download portable .NET runtime.
Get-Dotnet `
    -Version              $DotnetVersion `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $runtimeDirectory "dotnet") `
    -Clean

# Download OpenJDK binaries.
Get-OpenJdkBinaries `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $runtimeDirectory "jdk") `
    -Clean

# Download Node.js runtime.
Get-NodeJs `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $runtimeDirectory "nodejs") `
    -Clean

# Download VS Code portable build.
Get-VSCode `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $utilitiesDirectory "vs-code") `
    -Clean

# Download + extract Powershell Core.
Get-PowershellCore `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $utilitiesDirectory "powershell")

# GitHub Release Tools
foreach ($tool in $tools) {

    # Skip Windows-only tools when not running on Windows.
    if ($tool.WindowsOnly -and $OperatingSystem.ToUpper() -ne "WINDOWS") {
        continue
    }

    # Download + extract GitHub release artifact.
    #
    # Notes:
    #   - AssetPattern filters correct release file
    #   - DestinationFile optionally renames artifact
    Get-G4Artifact `
        -ArchiveDirectory     $workDirectory `
        -AssetPattern         $tool.AssetPattern `
        -DestinationDirectory $tool.DestinationDirectory `
        -DestinationFile      $tool.DestinationFile `
        -GitHubRepository     $tool.GitHubRepository
}

# VSIX Extensions (Offline Packaging)
foreach ($vscodeExtension in $vscodeExtensions) {

    # Retry policy for each extension download.
    $maxRetries = 3
    $success = $false

    # Attempt to download the VSIX up to $maxRetries times.
    for ($attempt = 1; $attempt -le $maxRetries -and -not $success; $attempt++) {
        try {
            # Download VSIX package for the current extension.
            #
            # Notes:
            #   - -ErrorAction Stop ensures failures are caught by try/catch.
            #   - DestinationDirectory is the offline VSIX cache folder.
            Get-VSCodeVsix `
                -Plugin               $vscodeExtension `
                -DestinationDirectory (Join-Path $utilitiesDirectory "vsixs") `
                -ErrorAction          Stop

            # Mark success so the retry loop stops for this extension.
            $success = $true
        }
        catch {
            # If we still have retries left, wait 3 seconds and try again.
            if ($attempt -lt $maxRetries) {
                Write-Host `
                    "VSIX download failed for '$($vscodeExtension)' (attempt $($attempt) of $($maxRetries)). Retrying in 3 seconds..." `
                    -ForegroundColor DarkGray

                Start-Sleep -Seconds 3
            }
            else {
                # Final failure: warn and move to the next extension.
                Write-Warning "VSIX download failed for '$($vscodeExtension)' after $($maxRetries) attempts."
                continue
            }
        }
    }
}

# Define all sandbox copy operations in a single collection.
#
# Each entry contains:
#   Path        -> Source path (supports wildcards when copying contents)
#   Destination -> Target directory that will be ensured before copy
#
# Notes:
# - Wildcard (*) means "copy contents of folder"
# - No wildcard means "copy the folder itself"
# - Using a table-driven approach keeps the logic clean and scalable
$sandboxSources = @(
    @{
        # Copy g4-cli contents into bot-root
        Path        = (Join-Path $sourceDirectory "g4-cli\*")
        Destination = (Join-Path $stageDirectory "bot-root")
    },
    @{
        # Copy selenium grid configuration files
        Path        = (Join-Path $sourceDirectory "selenium-grid\*")
        Destination = ([System.IO.Path]::Combine($stageDirectory, "selenium-grid", "configurations"))
    },
    @{
        # Copy the entire docker folder (no wildcard = include folder root)
        Path        = (Join-Path $sourceDirectory "docker")
        Destination = $stageDirectory
    },
    @{
        # Copy docker-compose files
        Path        = (Join-Path $sourceDirectory "docker-compose\*")
        Destination = (Join-Path $stageDirectory "docker-compose")
    },
    @{
        # Copy the entire k8s folder
        Path        = (Join-Path $sourceDirectory "k8s")
        Destination = $stageDirectory
    },
    @{
        # Copy utilities scripts into utilities/scripts
        Path        = (Join-Path $sourceDirectory "utilities\*")
        Destination = (Join-Path $utilitiesDirectory "scripts")
    }
)

# Iterate through each copy definition and execute safely
foreach ($sandboxSource in $sandboxSources) {

    # ---------------------------------------------------------------------
    # Ensure destination directory exists BEFORE copy.
    # This prevents the classic PowerShell issue where:
    #   - Single file copy -> destination treated as file
    #   - Multiple files   -> destination treated as directory
    #
    # -Force makes this idempotent and CI-safe.
    # ---------------------------------------------------------------------
    New-Item `
        -ItemType Directory `
        -Path     $sandboxSource.Destination `
        -Force `
    | Out-Null

    # ---------------------------------------------------------------------
    # Perform recursive copy.
    #
    # Behavior:
    # -Recurse -> include subfolders
    # -Force   -> overwrite existing files and bypass read-only
    #
    # Because we pre-created the directory, this is now deterministic
    # for 0 / 1 / many files.
    # ---------------------------------------------------------------------
    Copy-Item `
        -Path        $sandboxSource.Path `
        -Destination $sandboxSource.Destination `
        -Recurse `
        -Force
}

# Remove existing sandbox directory if requested.
#
# Notes:
#   - SilentlyContinue avoids noise if the directory does not exist.
#   - LiteralPath avoids wildcard interpretation.
if ($Clean) {
    $ProgressPreference = 'SilentlyContinue'
    Remove-Item `
        -LiteralPath $sandboxDirectory `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
    $ProgressPreference = 'Continue'
}

# Ensure the sandbox root directory exists.
New-Item -ItemType Directory -Path $sandboxDirectory -Force | Out-Null

# Resolve and normalize the stage root ONCE (important for performance).
#
# Notes:
#   - TrimEnd ensures consistent substring math later.
$stageRoot = (Resolve-Path $stageDirectory).Path.TrimEnd('\', '/')

# Get all FILES to copy (not directories), so progress can reach 100%.
#
# Notes:
#   - Using "*" ensures contents of the directory, not the directory itself.
#   - -File ensures we count/copy only files (no folders).
#   - -Force includes hidden/system files.
$items = Get-ChildItem -Path $stageDirectory -Recurse -Force -File
$total = $items.Count
$index = 0
$lastIndex = -1

foreach ($item in $items) {

    # Resolve full normalized path of the current file.
    # (Resolve-Path can be slower; keep it if you want canonical paths.)
    $fullPath = (Resolve-Path $item.FullName).Path

    # Safety check: ensure we only copy from inside stageRoot.
    if (-not $fullPath.StartsWith($stageRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "Item path is not under stage directory: $($fullPath)"
        continue
    }

    # Build destination path while preserving the stageRoot-relative structure.
    $relativePath = $fullPath.Substring($stageRoot.Length).TrimStart('\', '/')
    $destinationPath = Join-Path $sandboxDirectory $relativePath

    # Ensure destination directory exists.
    $destDir = Split-Path $destinationPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Copy the file, then increment progress counter.
    Copy-Item -Path $item.FullName -Destination $destinationPath -Force
    $index++

    # Compute percent based on FILES completed.
    $percent = if ($total -gt 0) { [int](($index / $total) * 100) } else { 100 }

    # Update progress only when counter changes (cheap throttle).
    if ($index -ne $lastIndex) {
        Write-Progress `
            -Activity        "Copying files to sandbox" `
            -Status          "$($percent)% complete ($index/$total)" `
            -PercentComplete $percent
        $lastIndex = $index
    }
}

# Force a final 100% update so the UI always completes cleanly.
Write-Progress `
    -Activity        "Copying files to sandbox" `
    -Status          "100% complete ($total/$total)" `
    -PercentComplete 100 `
    -Completed

# Remove directory recursively.
#
# Notes:
#   - Suppresses noisy internal progress ("Removing X items") in PS7+.
#   - Uses -LiteralPath to avoid wildcard interpretation.
#   - -ErrorAction Stop ensures failures are caught by try/catch.
$ProgressPreference = 'SilentlyContinue'

try {
    Write-Host "Removing sandbox directory..." -ForegroundColor DarkGray
    Write-Host "Target: $baseDirecotry" -ForegroundColor DarkGray

    Remove-Item `
        -LiteralPath $baseDirecotry `
        -Recurse `
        -Force `
        -ErrorAction Stop

    # Success message
    Write-Host "Directory removed successfully." -ForegroundColor DarkGray
}
catch {
    # Provide meaningful warning with context.
    Write-Warning "Failed to remove directory: $($baseDirecotry)"
    Write-Warning "Reason: $($_.Exception.Message)"
}
finally {
    # Always restore progress behavior to avoid global side effects.
    $ProgressPreference = 'Continue'
}

# Create or overwrite .env
$envFile = @"
G4_HUB_URI=$($HubUri)
G4_LICENSE_TOKEN=
G4_REGISTRATION_TIMEOUT=60
G4_WATCHDOG_INTERVAL=60

BOT_NAME
BOT_VOLUME=$($BotVolume)

DRIVER_BINARIES=
"@

$envFile | Set-Content -Path (Join-Path $sandboxDirectory ".env") -Encoding UTF8

# Mark progress as completed.
Write-Progress -Activity "Copying files to sandbox" -Completed

Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host "   G4 Sandbox creation completed successfully"                -ForegroundColor Green
Write-Host "   Location: $($sandboxDirectory)"                            -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host ""
