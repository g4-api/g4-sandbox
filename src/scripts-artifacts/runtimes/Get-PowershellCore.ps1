<#
.SYNOPSIS
    Downloads and extracts a portable PowerShell Core release for a specific
    operating system.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.
    Resolves the latest 'PowerShell/PowerShell' GitHub release, selects the
    platform-specific x64 archive, downloads it into an archive directory,
    and extracts it into a destination directory. On Linux/macOS targets, the
    extracted 'pwsh' executable is marked executable via chmod.

    This script is fully self-contained: it embeds its own copy of the
    GitHub release resolution/download/extraction logic so it can run
    without depending on any other script in this repository.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Normalize OS and resolve the expected GitHub asset pattern.
#
# Notes:
#   - PowerShell releases use platform-specific naming
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

# Ensure working directories exist.
New-Item -ItemType Directory -Path $ArchiveDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null

# Resolve the latest 'PowerShell/PowerShell' GitHub release metadata.
#
# Notes:
#   - GitHub requires a User-Agent header even for unauthenticated API calls
#   - Subject to unauthenticated rate limits (typically 60 requests/hour per IP)
$headers = @{
    "Accept"     = "application/vnd.github+json"
    "User-Agent" = "PowerShell/$($PSVersionTable.PSVersion)"
}

$apiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"

try {
    $release = Invoke-RestMethod `
        -Uri         $apiUrl `
        -Method      Get `
        -Headers     $headers `
        -UseBasicParsing `
        -ErrorAction Stop
}
catch {
    throw "Failed to retrieve GitHub release information from: $($apiUrl). $($_.Exception.Message)"
}

if (-not $release.tag_name -or -not $release.assets -or $release.assets.Length -eq 0) {
    throw "GitHub release metadata for 'PowerShell/PowerShell' is incomplete or has no assets."
}

$asset = $release.assets | Where-Object { [Regex]::IsMatch($_.name, $assertPattern) } | Select-Object -First 1
if (-not $asset -or -not $asset.browser_download_url) {
    throw "No release asset matching pattern '$($assertPattern)' was found in release '$($release.tag_name)'."
}

$downloadUrl = $asset.browser_download_url
$fileName = if ($DestinationFile) { $DestinationFile } else { $asset.name }
$archiveFilePath = Join-Path $ArchiveDirectory $fileName

Write-Host "Downloading PowerShell Core release artifact from '$($downloadUrl)' to '$($archiveFilePath)'" -ForegroundColor DarkGray

Invoke-WebRequest `
    -Uri     $downloadUrl `
    -OutFile $archiveFilePath `
    -UseBasicParsing

# Extract the archive into the destination directory.
#
# Notes:
#   - .zip: Expand-Archive
#   - .tar.gz / .tgz / .tar.xz: tar
Write-Host "Extracting archive '$($archiveFilePath)' into: '$($DestinationDirectory)'" -ForegroundColor Cyan

if ($archiveFilePath.EndsWith(".zip")) {
    Expand-Archive `
        -LiteralPath     $archiveFilePath `
        -DestinationPath $DestinationDirectory `
        -Force
}
elseif ($archiveFilePath.EndsWith(".tar.gz") -or $archiveFilePath.EndsWith(".tgz") -or $archiveFilePath.EndsWith(".tar.xz")) {
    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) {
        throw "Cannot extract tar archive because 'tar' was not found on PATH. Archive: '$($archiveFilePath)'"
    }

    & $tar.Source -xf $archiveFilePath -C $DestinationDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "tar extraction failed for: '$($archiveFilePath)' (exit code: $($LASTEXITCODE))."
    }
}
else {
    throw "Unsupported archive format for: '$($archiveFilePath)'."
}

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
