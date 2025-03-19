param(
    [string]$HubUri   = "http://localhost:4444/wd/hub",
    [int]   $NodePort = 5553
)

function Join-Paths {
    <#
    .SYNOPSIS
        Concatenates multiple paths into a single path string.

    .DESCRIPTION
        Join-Paths takes multiple string paths, iterates over them, and combines
        them into one unified path using the built-in Join-Path cmdlet.

    .PARAMETER Paths
        An array of string paths to be combined.

    .EXAMPLE
        Join-Paths "C:\folder1", "subfolder2", "file.txt"
        Returns: C:\folder1\subfolder2\file.txt

    .NOTES
        - This function is particularly useful when you have a list of directories
          or files that need to be systematically combined into a valid path.
        - It wraps a loop around the built-in Join-Path cmdlet.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    # Start by setting the result to the first path in the array
    $result = $Paths[0]

    # Loop through the remaining paths and continuously join them
    for ($i = 1; $i -lt $Paths.Length; $i++) {
        $result = Join-Path -Path $result -ChildPath $Paths[$i]
    }

    # Return the fully combined path
    return $result
}

# Determine if the OS platform is Linux
$isLinuxOs = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)

# Define base directory (the directory containing the script)
$baseFolder = $PSScriptRoot

# Define default folder names (alphabetically sorted)
$binariesFolder       = Join-Paths @($baseFolder, "binaries")
$configurationsFolder = Join-Paths @($baseFolder, "configurations")
$driversFolder        = Join-Paths @($baseFolder, "drivers-windows")
$edgeDriverExecutable = Join-Paths @($driversFolder, "msedgedriver")
$javaFolder           = Join-Paths @($baseFolder, "..", "..", "runtime", "jdk-windows")

# If the script is running on a Linux machine, replace "-Windows" with "-linux" in relevant folders
if ($isLinuxOs) {
    $driversFolder = $driversFolder -replace "-Windows", "-linux"
    $javaFolder    = $javaFolder    -replace "-Windows", "-linux"
}

# Build the path to the dotnet executable (dotnet[.exe] or similar) and other executables
$edgeDriverExecutable = Join-Paths @($driversFolder, "msedgedriver")
$javaExecutable       = Join-Paths @($javaFolder, "bin", "java")
$seleniumExecutable   = Join-Paths @($binariesFolder, "selenium-server.jar")

Write-Host "Starting EdgeDriver on port 9515..."
Start-Process `
    -FilePath $edgeDriverExecutable `
    -ArgumentList "--port=9515" `
    -WorkingDirectory $driversFolder

Write-Host "Registering Edge Node on port $($NodePort)..."
Start-Process `
    -FilePath         $javaExecutable `
    -ArgumentList     "-jar $($seleniumExecutable) node --hub $($hubUri) --config $(Join-Paths -Paths @($configurationsFolder, 'edge-node.toml')) --port $($NodePort)" `
    -WorkingDirectory $binariesFolder