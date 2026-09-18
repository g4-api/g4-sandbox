<#
.SYNOPSIS
    Clones one or more shallow, single-branch Git repository snapshots and
    strips their Git metadata so only source files are published.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.
    Accepts an array of repository snapshot definitions and, for each one,
    performs a shallow ('--depth 1') clone of a single branch into a
    destination directory, then removes the '.git' folder so the published
    sandbox carries source files only (no Git history/metadata).

    Each snapshot definition is a hashtable with the following keys:
      - Url                    [string]  Git repository URL, e.g.
                                          "https://github.com/g4-api/g4-services.git"
      - Branch                 [string]  Branch head to clone (defaults to "main")
      - DestinationDirectory   [string]  Source snapshot location
      - Clean                  [bool]    Remove and recreate the destination before cloning

    An optional GitHub personal access token (PAT) can be supplied via
    -Token to clone private repositories. When provided, it is injected into
    the clone URL as 'x-access-token:<token>@' for HTTPS URLs only; SSH URLs
    are cloned unmodified (the caller is expected to have SSH auth configured).

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)

.ASSUMPTIONS
    - 'git' is available on PATH
#>
[CmdletBinding()]
param(
    # Collection of repository snapshot definitions to clone. See
    # .DESCRIPTION for the expected hashtable shape of each entry.
    [Parameter(Mandatory = $true)]
    [array]$Snapshots,

    # Optional GitHub personal access token (PAT) for cloning private
    # repositories over HTTPS.
    [string]$Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Function: Get-GitRepositorySnapshot
#
# Purpose:
#   Clones a shallow, single-branch snapshot of a single Git repository and
#   removes its '.git' metadata directory afterwards.
# ---------------------------------------------------------------------------
function Get-GitRepositorySnapshot {
    [CmdletBinding()]
    param(
        [string]$Url,
        [string]$Branch = "main",
        [string]$DestinationDirectory,
        [switch]$Clean,
        [string]$Token
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        throw "Repository URL was not provided."
    }

    if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
        throw "Repository snapshot destination directory was not provided."
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        throw "Cannot clone repository snapshot because 'git' was not found on PATH."
    }

    if ($Clean -and (Test-Path -LiteralPath $DestinationDirectory)) {
        Write-Host "Clean repository snapshot requested. Removing existing destination directory: '$($DestinationDirectory)'" -ForegroundColor DarkGray

        $ProgressPreference = 'SilentlyContinue'
        Remove-Item `
            -LiteralPath $DestinationDirectory `
            -Recurse `
            -Force
        $ProgressPreference = 'Continue'
    }

    $parentDirectory = Split-Path -Path $DestinationDirectory -Parent
    New-Item -Path $parentDirectory -ItemType Directory -Force | Out-Null

    # Inject the PAT into the clone URL for private HTTPS repositories.
    #
    # Notes:
    #   - Only HTTPS URLs are rewritten; SSH URLs are left untouched
    #   - The token is never written to disk or logged
    $cloneUrl = $Url
    if (-not [string]::IsNullOrWhiteSpace($Token) -and $Url -match '^https://') {
        $cloneUrl = $Url -replace '^https://', "https://x-access-token:$($Token)@"
    }

    Write-Host "Cloning repository snapshot '$($Url)' branch '$($Branch)' into: '$($DestinationDirectory)'" -ForegroundColor DarkGray

    & $git.Source clone --depth 1 --branch $Branch --single-branch $cloneUrl $DestinationDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone repository snapshot '$($Url)' branch '$($Branch)' (exit code: $($LASTEXITCODE))."
    }

    $gitDirectory = Join-Path $DestinationDirectory ".git"
    if (Test-Path -LiteralPath $gitDirectory) {
        $ProgressPreference = 'SilentlyContinue'
        Remove-Item `
            -LiteralPath $gitDirectory `
            -Recurse `
            -Force
        $ProgressPreference = 'Continue'
    }

    if (Test-Path -LiteralPath $gitDirectory) {
        throw "Repository snapshot still contains Git metadata: '$($gitDirectory)'"
    }

    Write-Host "Repository snapshot completed. Destination directory: '$($DestinationDirectory)'" -ForegroundColor Cyan
}

# Clone every requested repository snapshot.
foreach ($snapshot in $Snapshots) {
    Get-GitRepositorySnapshot `
        -Url                  $snapshot.Url `
        -Branch               $snapshot.Branch `
        -DestinationDirectory $snapshot.DestinationDirectory `
        -Clean:$($snapshot.Clean) `
        -Token                $Token
}
