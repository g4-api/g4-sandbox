<#
-------------------------------------------------------------------------------
Script:     Start-UiaDriver.ps1 (example)
Purpose:    Starts the Windows UIA Driver Server using the bundled .NET runtime.
Description:
    This script resolves the portable dotnet runtime and UIA Driver DLL
    relative to the script directory, then launches the driver on the
    specified service port.

    Designed for portable/offline sandbox deployments.

Compatibility:
    - PowerShell 5.1+
    - Windows only (exits cleanly on non-Windows)

Assumptions:
    - Bundled dotnet exists at:     ..\runtime\dotnet\dotnet
    - UIA Driver exists at:         ..\drivers\uia-driver-server\Uia.DriverServer.dll
-------------------------------------------------------------------------------
#>

param(
    # Port exposed by the UIA Driver service.
    # Default aligns with typical UIA node expectations.
    [int]$ServicePort = 5555
)

# ---------------------------------------------------------------------------
# Scriptblock: Join multiple path segments safely
#
# Notes/Behavior:
#   - Used instead of manual string concatenation
#   - Keeps path handling platform-safe
# ---------------------------------------------------------------------------
$joinPaths = {
    param([string[]]$Paths)

    # Start from the first segment
    $result = $Paths[0]

    # Join remaining segments sequentially
    for ($i = 1; $i -lt $Paths.Length; $i++) {
        $result = Join-Path -Path $result -ChildPath $Paths[$i]
    }

    return $result
}

# ---------------------------------------------------------------------------
# Resolve base directory (directory containing this script)
# ---------------------------------------------------------------------------
$baseFolder = $PSScriptRoot

# ---------------------------------------------------------------------------
# OS guard: UIA Driver is Windows-specific
#
# Notes/Behavior:
#   - Exit 0 intentionally (not an error) when not on Windows
# ---------------------------------------------------------------------------
if ([Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    Write-Host "Detected non-Windows OS. UIA Driver is Windows-specific. Exiting..."
    exit 0
}

# ---------------------------------------------------------------------------
# Resolve sandbox folders
# ---------------------------------------------------------------------------
$dotnetFolder  = & $joinPaths -Paths @($baseFolder, "..", "runtime", "dotnet")
$driversFolder = & $joinPaths -Paths @($baseFolder, "..", "drivers")

# UIA driver working directory (required for Push-Location)
$uiaDriverFolder = & $joinPaths -Paths @($driversFolder, "uia-driver-server")

# ---------------------------------------------------------------------------
# Resolve executables
# ---------------------------------------------------------------------------
$dotnetExecutable    = & $joinPaths -Paths @($dotnetFolder, "dotnet")
$uiaDriverExecutable = & $joinPaths -Paths @($driversFolder, "uia-driver-server", "Uia.DriverServer.dll")

# ---------------------------------------------------------------------------
# Start UIA Driver
#
# Notes/Behavior:
#   - Runs in foreground (intentional)
#   - Uses Push/Pop-Location to ensure relative file safety
# ---------------------------------------------------------------------------
Write-Host "Starting UIA Driver (Windows-specific) on port $ServicePort..."

# Temporarily switch to the UIA driver directory
Push-Location $uiaDriverFolder

try {
    # Launch the UIA driver via bundled dotnet runtime
    & $dotnetExecutable "$uiaDriverExecutable" --port $ServicePort
}
finally {
    # Always restore previous working directory
    Pop-Location
}