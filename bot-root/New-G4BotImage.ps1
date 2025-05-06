<# 
    .SYNOPSIS
        Builds the g4-bot-runner Docker image.

    .DESCRIPTION
        This script runs Docker build using the specified Dockerfile 
        (./docker/g4-bot-runner.Dockerfile by default) and tags the 
        resulting image as g4-bot-runner:latest.

    .PARAMETER DockerfilePath
        Path to the Dockerfile to use for building.

    .PARAMETER ImageTag
        The tag (name:tag) you want to assign to the built image.

    .EXAMPLE
        PS> .\New-G4BotImage.ps1 -DockerfilePath "./docker/some-other.Dockerfile" -ImageTag "my-bot:latest"
        Builds using an alternative Dockerfile and tag.
#>
param (
    [Parameter(Mandatory=$true)]
    [string]$DockerfilePath,

    [Parameter(Mandatory=$true)]
    [string]$ImageTag
)

Write-Host "Building Docker image '$ImageTag' using Dockerfile at '$DockerfilePath'..."
try {
    docker build -f $DockerfilePath --no-cache -t $ImageTag .
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker image '$ImageTag' built successfully."
    }
    else {
        Write-Error "Docker build failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
}
catch {
    Write-Error "An error occurred during the Docker build: $_"
    exit 1
}
