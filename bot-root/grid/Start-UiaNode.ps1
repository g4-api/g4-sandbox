param(
    [string]$HubUri   = "http://localhost:4444/wd/hub",
    [int]   $NodePort = 5554
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
$isLinuxOs = $false
if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Unix) {
    $isLinuxOs = $true
}

# Define base directory (the directory containing the script)
$baseFolder = $PSScriptRoot

# Define default folder names (alphabetically sorted)
$binariesFolder       = Join-Paths @($baseFolder, "binaries")
$configurationsFolder = Join-Paths @($baseFolder, "configurations")
$dotnetFolder         = Join-Paths @($baseFolder, "..", "..", "runtime", "dotnet-windows")
$driversFolder        = Join-Paths @($baseFolder, "drivers-windows")
$javaFolder           = Join-Paths @($baseFolder, "..", "..", "runtime", "jdk-windows")
$uiaDriverFolder      = Join-Paths @($driversFolder, "uia-driver-server")

# If running on Linux, exit because UIA Driver is Windows-specific.
if ($isLinuxOs) {
    Write-Host "Detected Linux OS. UIA Driver is Windows-specific. Exiting..."
    Exit 0
}

# Build the path to the dotnet executable (dotnet[.exe] or similar) and other executables
$dotnetExecutable       = Join-Paths @($dotnetFolder, "dotnet")
$javaExecutable         = Join-Paths @($javaFolder, "bin", "java")
$seleniumExecutable     = Join-Paths @($binariesFolder, "selenium-server.jar")
$uiaDriverExecutable    = Join-Paths @($uiaDriverFolder, "Uia.DriverServer.dll")

Write-Host "Starting UIA Driver (Windows-specific)..."
Start-Process -FilePath $dotnetExecutable -ArgumentList $uiaDriverExecutable -WorkingDirectory $uiaDriverFolder

Write-Host "Registering UIA Node on port $($NodePort)..."
Start-Process `
    -FilePath         $javaExecutable `
    -ArgumentList     "-jar $($seleniumExecutable) node --hub $($HubUri) --config $(Join-Paths -Paths @($configurationsFolder, 'uia-node.toml')) --port $($NodePort)" `
    -WorkingDirectory $binariesFolder