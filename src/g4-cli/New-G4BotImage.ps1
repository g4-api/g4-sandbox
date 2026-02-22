# ---------------------------------------------------------------------------
# Script: Docker Image Builder
#
# Purpose:
#   Builds a Docker image from a specified Dockerfile using a clean,
#   deterministic build process.
#
# Description:
#   - Resolves the parent directory of the current script (typically repo root)
#   - Temporarily switches to that directory as the Docker build context
#   - Executes `docker build` with --no-cache to ensure a fresh build
#   - Validates the Docker exit code and fails the script when the build fails
#   - Always restores the original working directory
#
# Compatibility:
#   - PowerShell 5.x (Windows)
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Docker CLI is installed and available on PATH
#   - The Docker daemon is running and accessible
#   - The provided Dockerfile path is valid relative to the script parent
#   - The build context (.) contains all files required by the Dockerfile
# ---------------------------------------------------------------------------

param (
    # Path to the Dockerfile relative to the repository root (script parent).
    #
    # Notes:
    #   - This script changes directory to the script parent before building
    #   - Keep this path relative to that working directory (unless you pass an absolute path)
    [Parameter(Mandatory = $true)]
    [string]$DockerfilePath,

    # Docker image tag to build (name:tag).
    #
    # Examples:
    #   g4-cron-bot:latest
    #   g4-cron-bot:2026.02.22.1
    [Parameter(Mandatory = $true)]
    [string]$ImageTag
)

# Capture the parent directory of the current script.
#
# Notes:
#   - $PSScriptRoot is the directory containing this .ps1
#   - Script parent is typically the repo root (or one level above scripts/)
$scriptParent = Split-Path -Parent $PSScriptRoot

Write-Host "Switching to script parent directory: '$($scriptParent)'"

# Push the current location so we can safely return even if the build fails.
Push-Location $scriptParent
try {
    Write-Host "Building Docker image '$($ImageTag)' using Dockerfile at '$($DockerfilePath)'..."

    # Build the Docker image.
    #
    # Notes:
    #   - -f selects the Dockerfile path
    #   - --no-cache forces a clean build (no layer reuse)
    #   - -t sets the image tag
    #   - "." is the build context (must include everything the Dockerfile COPYs)
    docker build -f $DockerfilePath --no-cache -t $ImageTag .

    # Validate build result using the last native process exit code.
    if ($LASTEXITCODE -eq 0) {

        # Success path.
        Write-Host "Docker image '$($ImageTag)' built successfully."
    }
    else {

        # Failure path: propagate the docker exit code for CI correctness.
        Write-Error "Docker build failed with exit code $($LASTEXITCODE)."
        exit $LASTEXITCODE
    }
}
catch {
    # Catch PowerShell exceptions (e.g. docker command not found, permission issues, etc.).
    #
    # Notes:
    #   - docker build failures usually set $LASTEXITCODE and won't always throw,
    #     but missing docker / execution failures can throw.
    Write-Error "An error occurred during the Docker build: $($_)"
    exit 1
}
finally {
    # Always restore the original working directory.
    Pop-Location
    Write-Host "Returned to original location."
}
