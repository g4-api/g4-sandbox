<#
.SYNOPSIS
    Downloads one or more VS Code extensions (VSIX packages) for offline
    installation, including their transitive dependencies.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.
    Accepts an array of VS Code extension identifiers ('publisher.extension')
    and downloads each one (plus its ExtensionDependencies / ExtensionPack
    dependencies, recursively) as a versioned .vsix file into a shared
    destination directory.

    Each extension download is retried up to 3 times before being reported as
    a failure; failures are non-fatal so the remaining extensions in the list
    still get processed.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
[CmdletBinding()]
param(
    # VS Code extension identifiers to download, each in 'publisher.extension' form.
    # Example: @('ms-python.python', 'ms-vscode.powershell')
    [Parameter(Mandatory = $true)]
    [string[]]$Plugins,

    # Destination directory where VSIX files will be saved.
    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory,

    # When specified, removes the destination directory before downloads.
    # This guarantees a clean, deterministic destination state.
    [Switch]$Clean,

    # Number of download attempts per top-level extension before it is
    # reported as failed and skipped.
    [int]$MaxRetries = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Function: Get-VSCodeVsix
#
# Purpose:
#   Downloads a single VS Code extension (and recursively, its dependencies)
#   as a versioned .vsix file into the destination directory.
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

# Clean the shared destination directory once, up front, if requested.
if ($Clean -and (Test-Path -Path $DestinationDirectory)) {
    Write-Host "Clean installation requested. Removing existing destination directory: '$($DestinationDirectory)'" -ForegroundColor DarkGray

    $ProgressPreference = 'SilentlyContinue'
    Remove-Item -Path $DestinationDirectory -Recurse -Force
    $ProgressPreference = 'Continue'
}

New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null

# Download every requested top-level extension, retrying transient failures.
foreach ($plugin in $Plugins) {

    $success = $false

    for ($attempt = 1; $attempt -le $MaxRetries -and -not $success; $attempt++) {
        try {
            Get-VSCodeVsix `
                -Plugin               $plugin `
                -DestinationDirectory $DestinationDirectory `
                -ErrorAction          Stop

            $success = $true
        }
        catch {
            if ($attempt -lt $MaxRetries) {
                Write-Host `
                    "VSIX download failed for '$($plugin)' (attempt $($attempt) of $($MaxRetries)). Retrying in 3 seconds..." `
                    -ForegroundColor DarkGray

                Start-Sleep -Seconds 3
            }
            else {
                Write-Warning "VSIX download failed for '$($plugin)' after $($MaxRetries) attempts. $($_.Exception.Message)"
            }
        }
    }
}
