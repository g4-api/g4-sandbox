<#
.SYNOPSIS
    Downloads the portable Windows Terminal build (Windows target only).

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.
    Resolves the latest 'microsoft/terminal' release, verifies the release
    asset's published SHA-256 digest, downloads and extracts it, and enables
    portable mode so Windows Terminal stores its settings locally instead of
    under %LOCALAPPDATA%.

    This script is fully self-contained: it embeds its own copies of the
    GitHub asset resolution/verification/extraction helpers so it can run
    without depending on any other script in this repository.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
[CmdletBinding()]
param (
    # Directory used to store the downloaded archive file.
    [string]$ArchiveDirectory,

    # Destination directory where the archive will be extracted.
    [string]$DestinationDirectory,

    # When specified, removes the destination directory before extraction.
    [Switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Function: Resolve-VerifiedGitHubAsset
#
# Purpose:
#   Resolves the latest GitHub release for a repository and returns a single
#   asset (matched by a '{0}'-templated name) together with its verified
#   SHA-256 digest, so the download step can validate integrity.
# ---------------------------------------------------------------------------
function Resolve-VerifiedGitHubAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Repository,
        [Parameter(Mandatory = $true)] [string]$AssetNameTemplate
    )

    $headers = @{
        Accept = "application/vnd.github+json"
        "User-Agent" = "g4-sandbox-builder"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$Repository/releases/latest" `
        -Headers $headers `
        -Method Get `
        -UseBasicParsing

    if (-not $release.tag_name -or -not $release.assets) {
        throw "GitHub release metadata for '$Repository' is incomplete."
    }

    $versionMatch = [regex]::Match([string]$release.tag_name, '\d+(?:\.\d+)+(?:[-+][0-9A-Za-z.-]+)?')
    if (-not $versionMatch.Success) {
        throw "Could not parse a version from GitHub release tag '$($release.tag_name)'."
    }

    $assetName = $AssetNameTemplate -f $versionMatch.Value
    $asset = @($release.assets) | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    if (-not $asset) {
        throw "Asset '$assetName' was not found in release '$($release.tag_name)' of '$Repository'."
    }

    $digestProperty = $asset.PSObject.Properties["digest"]
    if (-not $digestProperty) {
        throw [System.Security.SecurityException]::new("Asset '$assetName' does not publish a SHA-256 digest.")
    }

    $digest = ([string]$digestProperty.Value).Trim().ToLowerInvariant() -replace '^sha256:', ''
    if ($digest -notmatch '^[0-9a-f]{64}$') {
        throw [System.Security.SecurityException]::new("Asset '$assetName' publishes an invalid SHA-256 digest.")
    }

    [pscustomobject]@{
        AssetName = $assetName
        DownloadUrl = [string]$asset.browser_download_url
        Headers = $headers
        Sha256 = $digest
        Tag = [string]$release.tag_name
    }
}

# ---------------------------------------------------------------------------
# Function: Receive-VerifiedGitHubAsset
#
# Purpose:
#   Downloads a resolved GitHub release asset and validates its SHA-256
#   digest against the value published by GitHub before returning its path.
# ---------------------------------------------------------------------------
function Receive-VerifiedGitHubAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object]$Asset,
        [Parameter(Mandatory = $true)] [string]$ArchiveDirectory
    )

    New-Item -ItemType Directory -Path $ArchiveDirectory -Force | Out-Null
    $archivePath = Join-Path $ArchiveDirectory $Asset.AssetName
    Write-Host "Downloading verified release asset: '$($Asset.AssetName)'" -ForegroundColor DarkGray
    Invoke-WebRequest `
        -Uri $Asset.DownloadUrl `
        -Headers $Asset.Headers `
        -OutFile $archivePath `
        -UseBasicParsing

    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $Asset.Sha256) {
        throw [System.Security.SecurityException]::new(
            "SHA-256 mismatch for '$($Asset.AssetName)'. Expected $($Asset.Sha256); received $actualHash.")
    }

    return $archivePath
}

# ---------------------------------------------------------------------------
# Function: Expand-PortableAgentArchive
#
# Purpose:
#   Extracts a downloaded archive (.zip via Expand-Archive, everything else
#   via tar) into a destination directory.
# ---------------------------------------------------------------------------
function Expand-PortableAgentArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$ArchivePath,
        [Parameter(Mandatory = $true)] [string]$DestinationPath
    )

    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    if ($ArchivePath.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
        Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestinationPath -Force
        return
    }

    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) {
        throw "Cannot extract '$ArchivePath' because tar is not available on PATH."
    }

    & $tar.Source -xf $ArchivePath -C $DestinationPath
    if ($LASTEXITCODE -ne 0) {
        throw "tar failed to extract '$ArchivePath' (exit code: $LASTEXITCODE)."
    }
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

# Ensure the destination directory exists (it may have been removed by -Clean).
New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null

# Resolve and verify the exact portable release asset.
#
# Notes:
#   - The '{0}' placeholder is replaced with the version parsed from the
#     release tag (e.g. 'v1.24.11911.0' -> '1.24.11911.0')
#   - Resolve-VerifiedGitHubAsset throws if the digest is missing/invalid
$asset = Resolve-VerifiedGitHubAsset `
    -Repository        'microsoft/terminal' `
    -AssetNameTemplate 'Microsoft.WindowsTerminal_{0}_x64.zip'

Write-Host "Resolved Windows Terminal release: $($asset.Tag) ($($asset.AssetName))" -ForegroundColor DarkGray

# Download the archive and validate its SHA-256 digest before use.
$archivePath = Receive-VerifiedGitHubAsset `
    -Asset            $asset `
    -ArchiveDirectory $ArchiveDirectory

# Extract the verified archive into the destination directory.
Write-Host "Extracting Windows Terminal archive '$($archivePath)' into: '$($DestinationDirectory)'" -ForegroundColor Cyan

Expand-PortableAgentArchive `
    -ArchivePath     $archivePath `
    -DestinationPath $DestinationDirectory

# Flatten the extracted folder structure.
#
# Notes:
#   - The x64 ZIP typically extracts into a single top-level directory
#     named 'terminal-<version>'
#   - When wt.exe is not already at the destination root, move the contents
#     of that single sub-directory up one level
$rootExecutable = Join-Path $DestinationDirectory 'wt.exe'

if (-not (Test-Path -LiteralPath $rootExecutable -PathType Leaf)) {

    $topLevelDirectory = Get-ChildItem -Path $DestinationDirectory -Directory -Force |
    Sort-Object Name |
    Select-Object -First 1

    if (-not $topLevelDirectory) {
        Write-Warning "No extracted top-level directory was found in '$($DestinationDirectory)'"
        return
    }

    Write-Host "Flattening extracted layout by moving contents from '$($topLevelDirectory.FullName)' to '$($DestinationDirectory)'" -ForegroundColor DarkGray

    Get-ChildItem -Path $topLevelDirectory.FullName -Force | Move-Item -Destination $DestinationDirectory -Force

    $ProgressPreference = 'SilentlyContinue'
    Remove-Item -Path $topLevelDirectory.FullName -Force
    $ProgressPreference = 'Continue'
}

# Verify the expected executables landed at the destination root.
foreach ($executableName in @('wt.exe', 'WindowsTerminal.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $DestinationDirectory $executableName) -PathType Leaf)) {
        Write-Warning "Expected '$($executableName)' was not found under '$($DestinationDirectory)' after extraction."
    }
}

# Enable portable mode.
#
# Notes:
#   - Creating a '.portable' marker next to WindowsTerminal.exe makes Windows
#     Terminal store its settings and runtime state in a local 'settings'
#     folder instead of %LOCALAPPDATA%, keeping the bundle self-contained
$portableMarker = Join-Path $DestinationDirectory '.portable'
Set-Content -LiteralPath $portableMarker -Value '' -Encoding ASCII -NoNewline

Write-Host "Windows Terminal deployed successfully (portable mode)." -ForegroundColor Cyan
Write-Host "Version:      $($asset.Tag)"           -ForegroundColor DarkGray
Write-Host "Destination:  $($DestinationDirectory)" -ForegroundColor DarkGray
Write-Host "Archive:      $($archivePath)"          -ForegroundColor DarkGray
