<#
.SYNOPSIS
    Downloads one or more GitHub branch source archives and flattens them
    into local destination directories.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.
    Accepts an array of archive definitions and, for each one, downloads the
    GitHub branch source zip (not a release asset), extracts it, and moves
    the single top-level "<repo>-<branch>" folder contents up one level so
    the source files land directly under the destination directory.

    Each archive definition is a hashtable with the following keys:
      - Repository            [string]  '<owner>/<repo>', e.g. "g4-api/g4-pytest-wrapper"
      - Branch                 [string]  Branch head to archive (defaults to "main")
      - DestinationDirectory   [string]  Where the flattened source will land
      - WindowsOnly            [bool]    When $true, skipped unless -OperatingSystem is "Windows"

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
[CmdletBinding()]
param(
    # Collection of archive definitions to download. See .DESCRIPTION for the
    # expected hashtable shape of each entry.
    [Parameter(Mandatory = $true)]
    [array]$Archives,

    # Directory used to store downloaded archives, shared by all entries.
    [Parameter(Mandatory = $true)]
    [string]$ArchiveDirectory,

    # Target operating system, used to decide whether "WindowsOnly" archives
    # should be skipped.
    [ValidateSet("Linux", "MacOs", "Windows")]
    [string]$OperatingSystem,

    # Optional GitHub personal access token (PAT), used to access private
    # repositories and to raise the unauthenticated rate limit.
    [string]$Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Function: Get-GitHubBranchArchive
#
# Purpose:
#   Downloads a single GitHub branch source archive (zip) and flattens it
#   into a local destination directory.
# ---------------------------------------------------------------------------
function Get-GitHubBranchArchive {
    [CmdletBinding()]
    param(
        [string]$Repository,
        [string]$Branch = "main",
        [string]$ArchiveDirectory,
        [string]$DestinationDirectory,
        [switch]$Clean,
        [string]$Token
    )

    $repositoryName = ($Repository -split '/')[-1]
    if ([string]::IsNullOrWhiteSpace($Repository) -or [string]::IsNullOrWhiteSpace($repositoryName) -or $Repository -notmatch '/') {
        Write-Warning "Repository must be in '<owner>/<repo>' form. Received: '$($Repository)'"
        return
    }

    if ($Clean -and (Test-Path -Path $DestinationDirectory)) {

        Write-Host "Clean installation requested. Removing existing destination directory: '$($DestinationDirectory)'" -ForegroundColor DarkGray

        $ProgressPreference = 'SilentlyContinue'
        Remove-Item `
            -Path    $DestinationDirectory `
            -Recurse `
            -Force
        $ProgressPreference = 'Continue'
    }

    New-Item -Path $ArchiveDirectory     -ItemType Directory -Force | Out-Null
    New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null

    $headers = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    }
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers['Authorization'] = "Bearer $($Token)"
    }

    # Build the branch-archive download URL.
    #
    # Example:
    #   https://github.com/g4-api/g4-pytest-wrapper/archive/refs/heads/main.zip
    $downloadUrl = "https://github.com/$($Repository)/archive/refs/heads/$($Branch).zip"

    # Build a deterministic archive filename to avoid collisions in the archive
    # directory (the raw asset name would just be "<branch>.zip").
    $fileName = "$($repositoryName)-$($Branch).zip"
    $outFile  = Join-Path -Path $ArchiveDirectory -ChildPath $fileName

    Write-Host "Downloading GitHub branch archive from '$($downloadUrl)' to: '$($outFile)'" -ForegroundColor DarkGray

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

    Write-Host "Extracting archive '$($outFile)' into destination directory: '$($DestinationDirectory)'" -ForegroundColor Cyan

    Expand-Archive `
        -Path            $outFile `
        -DestinationPath $DestinationDirectory `
        -Force

    # Flatten the extracted folder structure.
    #
    # Notes:
    #   - GitHub branch archives extract into a single top-level directory:
    #       <repo>-<branch>
    #   - This step moves all contents up one level to place the source files
    #     directly under the destination directory
    $topLevelDirectory = Get-ChildItem -Path $DestinationDirectory -Directory |
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

    Write-Host "GitHub branch archive installation completed. Destination directory: '$($DestinationDirectory)'" -ForegroundColor Cyan
}

# Download + extract every requested branch archive.
foreach ($archive in $Archives) {

    # Skip Windows-only archives when not running on Windows.
    if ($archive.WindowsOnly -and $OperatingSystem.ToUpper() -ne "WINDOWS") {
        continue
    }

    Get-GitHubBranchArchive `
        -Repository           $archive.Repository `
        -Branch               $archive.Branch `
        -ArchiveDirectory     $ArchiveDirectory `
        -DestinationDirectory $archive.DestinationDirectory `
        -Token                $Token
}
