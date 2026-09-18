<#
.SYNOPSIS
    Downloads one or more versioned G4 release artifacts from GitHub
    repositories and extracts them into local destination directories.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.
    Accepts an array of tool definitions and, for each one:
      - Resolves the requested release (explicit tag or latest available)
      - Optionally filters release assets by a name pattern
      - Downloads the archive into a shared archive directory
      - Extracts (or moves, for non-archive files) it into a per-tool
        destination directory

    Each tool definition is a hashtable with the following keys:
      - GitHubRepository     [string]  GitHub API repo URL, e.g.
                                        "https://api.github.com/repos/g4-api/g4-services"
      - Tag                   [string]  Optional explicit release tag.
      - AssetPattern          [string]  Optional regex to select a specific asset.
      - DestinationDirectory  [string]  Where the artifact will be extracted/moved.
      - DestinationFile       [string]  Optional rename of the downloaded asset.
      - WindowsOnly           [bool]    When $true, the tool is skipped unless
                                        -OperatingSystem is "Windows".

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
[CmdletBinding()]
param(
    # Collection of tool definitions to download. See .DESCRIPTION for the
    # expected hashtable shape of each entry.
    [Parameter(Mandatory = $true)]
    [array]$Tools,

    # Directory used to store downloaded archives, shared by all tools.
    [Parameter(Mandatory = $true)]
    [string]$ArchiveDirectory,

    # Target operating system, used to decide whether "WindowsOnly" tools
    # should be skipped.
    [ValidateSet("Linux", "MacOs", "Windows")]
    [string]$OperatingSystem,

    # Optional GitHub personal access token (PAT), used to raise the
    # unauthenticated rate limit and to access private repositories/assets.
    [string]$Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Function: Get-G4Artifact
#
# Purpose:
#   Downloads a single versioned release artifact from a GitHub repository
#   and extracts (or moves) it into a local destination directory.
# ---------------------------------------------------------------------------
function Get-G4Artifact {
    [CmdletBinding()]
    param(
        [string]$GitHubRepository,
        [string]$Tag,
        [string]$AssetPattern,
        [string]$ArchiveDirectory,
        [string]$DestinationDirectory,
        [string]$DestinationFile,
        [switch]$Clean,
        [string]$Token
    )

    # ------------------------------------------------------------------
    # Script block: Resolve-LatestVersion
    #
    # Resolves GitHub release metadata (latest release or a specific tag)
    # for a repository, and returns the resolved tag plus a download URL
    # for a matching release asset.
    # ------------------------------------------------------------------
    $resolveLatestVersion = {
        param(
            [string]$GitHubRepository,
            [string]$Tag,
            [string]$AssetPattern,
            [string]$Token
        )

        $apiUrl = if ($Tag) {
            "$($GitHubRepository)/releases/tags/$($Tag)"
        }
        else {
            "$($GitHubRepository)/releases/latest"
        }

        $headers = @{
            "Accept"     = "application/vnd.github+json"
            "User-Agent" = "PowerShell/$($PSVersionTable.PSVersion)"
        }
        if (-not [string]::IsNullOrWhiteSpace($Token)) {
            $headers["Authorization"] = "Bearer $($Token)"
        }

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

        $tagName = $response.tag_name
        if (-not $tagName) {
            Write-Warning "GitHub API response did not include a release tag (tag_name)."
            return $null
        }

        if (-not $response.assets -or $response.assets.Length -eq 0) {
            Write-Warning "GitHub release was resolved successfully, but no downloadable assets were found for this release."
            return $null
        }

        if (-not $AssetPattern -or [string]::IsNullOrEmpty($AssetPattern)) {
            $asset = $response.assets[0]
            $downloadUrl = $asset.browser_download_url
        }
        else {
            $asset = $response.assets | Where-Object { [Regex]::IsMatch($_.name, $AssetPattern) } | Select-Object -First 1
            $downloadUrl = $asset.browser_download_url
        }

        if (-not $downloadUrl) {
            Write-Warning "Release '$($tagName)' was found, but no downloadable release assets were returned."
            return $null
        }

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
    $release = & $resolveLatestVersion `
        -AssetPattern     $AssetPattern `
        -GitHubRepository $GitHubRepository `
        -Tag              $Tag `
        -Token            $Token

    if (-not $release) {
        Write-Error "Failed to resolve GitHub release information for '$($GitHubRepository)'. Aborting artifact download."
        return
    }

    $downloadUrl = $release.DownloadUrl

    # Ensure the archive directory exists.
    New-Item -ItemType Directory -Path $ArchiveDirectory -Force | Out-Null

    # Download the archive from GitHub to the specified file path.
    $archiveFilePath = Join-Path $ArchiveDirectory $release.FileName
    Write-Host "Downloading release artifact from '$($downloadUrl)' to '$($archiveFilePath)'" -ForegroundColor DarkGray

    $downloadHeaders = @{}
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $downloadHeaders["Authorization"] = "Bearer $($Token)"
    }

    Invoke-WebRequest `
        -Uri     $downloadUrl `
        -Headers $downloadHeaders `
        -OutFile $archiveFilePath `
        -UseBasicParsing

    # Supported archive extensions used to decide between "extract" vs "move".
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

    $fileName = [System.IO.Path]::GetFileName($archiveFilePath).ToLower()
    $isArchive = $archiveExtensions | Where-Object { $fileName.EndsWith($_) }
    $fileName = if (-not $DestinationFile) { $fileName } else { $DestinationFile }

    if (-not $isArchive) {
        Write-Host "File is not an archive. Moving without extraction:" -ForegroundColor Gray
        Write-Host "  $($archiveFilePath) -> $($DestinationDirectory)" -ForegroundColor Gray

        [System.IO.Directory]::CreateDirectory($DestinationDirectory) | Out-Null

        Move-Item `
            -LiteralPath $archiveFilePath `
            -Destination (Join-Path $DestinationDirectory $fileName) `
            -Force
    }
    else {
        Write-Host "Extracting archive:" -ForegroundColor Cyan
        Write-Host "  $($archiveFilePath) -> $($DestinationDirectory)" -ForegroundColor Cyan

        New-Item `
            -Path     $DestinationDirectory `
            -ItemType Directory `
            -Force `
        | Out-Null

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
            $tar = Get-Command tar -ErrorAction SilentlyContinue
            if (-not $tar) {
                Write-Warning "Cannot extract tar archive because 'tar' was not found on PATH. Archive: '$($archiveFilePath)'"
                return
            }

            & $tar.Source -xf $archiveFilePath -C $DestinationDirectory
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "tar extraction failed for: '$($archiveFilePath)' (exit code: $($LASTEXITCODE))."
                return
            }
        }
        else {
            Write-Warning "Unsupported archive format for: '$($archiveFilePath)'."
            return
        }
    }
}

# Download + extract every requested GitHub release tool definition.
foreach ($tool in $Tools) {

    # Skip Windows-only tools when not running on Windows.
    if ($tool.WindowsOnly -and $OperatingSystem.ToUpper() -ne "WINDOWS") {
        continue
    }

    Get-G4Artifact `
        -ArchiveDirectory     $ArchiveDirectory `
        -AssetPattern         $tool.AssetPattern `
        -DestinationDirectory $tool.DestinationDirectory `
        -DestinationFile      $tool.DestinationFile `
        -GitHubRepository     $tool.GitHubRepository `
        -Tag                  $tool.Tag `
        -Token                $Token
}
