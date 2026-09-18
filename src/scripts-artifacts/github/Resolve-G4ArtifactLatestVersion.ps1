<#
.SYNOPSIS
    Resolves the latest GitHub release tag for a repository.

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.
    Queries the GitHub REST API '/releases/latest' endpoint for a repository
    and returns the resolved release tag name (e.g. "v1.2.3"). Used to embed
    a deterministic version into the published sandbox output folder name.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)
#>
[CmdletBinding()]
param(
    # GitHub repository API base URL.
    #
    # Example:
    #   https://api.github.com/repos/org/repo
    #
    # Notes:
    #   - Script will append "/releases/latest"
    [string]$GitHubRepository,

    # Optional GitHub personal access token (PAT), used to access private
    # repositories and to raise the unauthenticated rate limit.
    [string]$Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
if (-not [string]::IsNullOrWhiteSpace($Token)) {
    $headers["Authorization"] = "Bearer $($Token)"
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
