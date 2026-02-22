<#
-------------------------------------------------------------------------------
Script:     Start-UiaNode.ps1 (example)
Purpose:    Starts the UIA Driver Server (Windows-only) and registers a UIA
            Selenium Grid node against a Hub.
Description:
    This script is intended for portable sandbox deployments. It resolves the
    bundled .NET runtime, bundled Java runtime, Selenium server JAR, and UIA
    Driver DLL relative to the script directory, then:

      1) Starts UIA Driver Server: dotnet Uia.DriverServer.dll
      2) Registers the UIA Selenium node using selenium-server.jar and the
         uia-node.toml configuration file

Compatibility:
    - PowerShell 5.1+
    - Windows only (exits cleanly on non-Windows)

Assumptions:
    - Bundled dotnet exists at:     ..\runtime\dotnet\dotnet
    - Bundled Java exists at:       ..\runtime\jdk\bin\java
    - Selenium server exists at:    ..\selenium-grid\selenium-server.jar
    - Selenium configs exist at:    ..\selenium-grid\configurations\uia-node.toml
    - UIA Driver exists at:         ..\drivers\uia-driver-server\Uia.DriverServer.dll
-------------------------------------------------------------------------------
#>

param(
    # Selenium Hub endpoint that the UIA node should register against.
    [string]$HubUri   = "http://localhost:4444/wd/hub",

    # Port exposed by this UIA node instance.
    [int]   $NodePort = 5554
)

function Join-Paths {
    <#
    ---------------------------------------------------------------------------
    Function:   Join-Paths
    Purpose:    Joins multiple path segments into a single path safely.
    Description:
        PowerShell's Join-Path joins two segments at a time. This helper accepts
        an array and joins them iteratively.

    Notes/Behavior:
        - Platform-safe path handling (though this script runs on Windows only)
        - Avoids manual string concatenation
    ---------------------------------------------------------------------------
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    # Start with the first segment as the base/root path.
    $result = $Paths[0]

    # Join remaining segments one-by-one.
    for ($i = 1; $i -lt $Paths.Length; $i++) {
        $result = Join-Path -Path $result -ChildPath $Paths[$i]
    }

    return $result
}

# ---------------------------------------------------------------------------
# OS guard: UIA Driver is Windows-specific.
#
# Notes/Behavior:
#   - Exit 0 to indicate "not an error" when running on non-Windows.
# ---------------------------------------------------------------------------
if ([Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    Write-Host "UIA Driver is Windows-specific. Skipping UIA node startup."
    exit 0
}

# ---------------------------------------------------------------------------
# Resolve base directory (directory containing this script)
# ---------------------------------------------------------------------------
$baseFolder = $PSScriptRoot

# ---------------------------------------------------------------------------
# Resolve sandbox folders (alphabetically sorted)
# ---------------------------------------------------------------------------
$binariesFolder       = Join-Paths @($baseFolder, "..", "selenium-grid")
$configurationsFolder = Join-Paths @($baseFolder, "..", "selenium-grid", "configurations")
$dotnetFolder         = Join-Paths @($baseFolder, "..", "runtime", "dotnet")
$driversFolder        = Join-Paths @($baseFolder, "..", "drivers")
$javaFolder           = Join-Paths @($baseFolder, "..", "runtime", "jdk")

# UIA driver directory (used as WorkingDirectory when launching the driver server)
$uiaDriverFolder      = Join-Paths @($driversFolder, "uia-driver-server")

# ---------------------------------------------------------------------------
# Resolve executables/artifacts
# ---------------------------------------------------------------------------
$dotnetExecutable    = Join-Paths @($dotnetFolder, "dotnet")
$javaExecutable      = Join-Paths @($javaFolder, "bin", "java")
$seleniumExecutable  = Join-Paths @($binariesFolder, "selenium-server.jar")
$uiaDriverExecutable = Join-Paths @($driversFolder, "uia-driver-server", "Uia.DriverServer.dll")

# ---------------------------------------------------------------------------
# Start UIA Driver Server
#
# Notes/Behavior:
#   - Runs: dotnet Uia.DriverServer.dll
#   - Working directory set to the UIA driver folder (helps with relative files)
# ---------------------------------------------------------------------------
Write-Host "Starting UIA Driver (Windows-specific)..."

Start-Process `
    -FilePath         $dotnetExecutable `
    -ArgumentList     $uiaDriverExecutable `
    -WorkingDirectory $uiaDriverFolder

# ---------------------------------------------------------------------------
# Register UIA Node with Selenium Hub
#
# Notes/Behavior:
#   - Uses TOML config to define capabilities/node behavior
#   - Registers against the provided HubUri
# ---------------------------------------------------------------------------
Write-Host "Registering UIA Node on port $($NodePort)..."

Start-Process `
    -FilePath         $javaExecutable `
    -ArgumentList     "-jar $($seleniumExecutable) node --hub $($HubUri) --config $(Join-Paths -Paths @($configurationsFolder, 'uia-node.toml')) --port $($NodePort)" `
    -WorkingDirectory $binariesFolder