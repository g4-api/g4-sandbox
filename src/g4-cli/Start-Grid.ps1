<#
-------------------------------------------------------------------------------
Script:     Start-SeleniumGrid.ps1 (example)
Purpose:    Starts a portable Selenium Grid Hub and registers local nodes
            (Chrome + optional Windows-only UIA node).
Description:
    This script is designed for a portable/offline sandbox layout. It resolves
    runtime and driver paths relative to the script directory, then:

      1) Starts Selenium Hub (Java + selenium-server.jar)
      2) (Windows only) Starts the UIA Driver Server (.NET) and registers a UIA node
      3) Starts ChromeDriver and registers a Chrome node

Compatibility:
    - PowerShell 5.1+
    - Windows/Linux supported (UIA branch runs only on Windows)
    - Requires a bundled Java runtime and Selenium server JAR

Assumptions:
    - Folder structure is preserved relative to the script location
    - Java runtime exists at: ..\runtime\jdk\bin\java
    - Selenium server exists at: ..\selenium-grid\selenium-server.jar
    - ChromeDriver exists at: ..\drivers\chrome\chromedriver
    - UIA Driver exists at: ..\drivers\uia-driver-server\Uia.DriverServer.dll (Windows only)
    - TOML configs exist under: ..\selenium-grid\configurations\
-------------------------------------------------------------------------------
#>

param(
    # Selenium Hub endpoint that nodes will register against.
    # Note: Hub is started locally by this script; this value is used for node registration.
    [string]$HubUri = "http://localhost:4444/wd/hub"
)

function Join-Paths {
    <#
    ---------------------------------------------------------------------------
    Function:   Join-Paths
    Purpose:    Joins multiple path segments into a single path safely.
    Description:
        PowerShell's Join-Path joins two segments at a time. This helper
        accepts an array and joins them iteratively.

    Notes/Behavior:
        - Platform-safe (Windows/Linux path separators)
        - Avoids brittle string concatenation
    ---------------------------------------------------------------------------
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    # Start from the first element as the "root" path.
    $result = $Paths[0]

    # Join remaining segments one-by-one.
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
# Resolve folder paths (alphabetically sorted for maintainability)
# ---------------------------------------------------------------------------
$binariesFolder       = Join-Paths @($baseFolder, "..", "selenium-grid")
$configurationsFolder = Join-Paths @($baseFolder, "..", "selenium-grid", "configurations")
$dotnetFolder         = Join-Paths @($baseFolder, "..", "runtime", "dotnet")
$driversFolder        = Join-Paths @($baseFolder, "..", "drivers")
$javaFolder           = Join-Paths @($baseFolder, "..", "runtime", "jdk")

# ---------------------------------------------------------------------------
# Resolve executables / artifacts
# Notes:
#   - No extensions are appended automatically (keeps it portable).
#   - Ensure these files exist in your sandbox layout.
# ---------------------------------------------------------------------------
$chromeDriverExecutable = Join-Paths @($driversFolder, "chrome", "chromedriver")
$dotnetExecutable       = Join-Paths @($dotnetFolder, "dotnet")
$javaExecutable         = Join-Paths @($javaFolder, "bin", "java")
$seleniumExecutable     = Join-Paths @($binariesFolder, "selenium-server.jar")
$uiaDriverExecutable    = Join-Paths @($driversFolder, "uia-driver-server", "Uia.DriverServer.dll")

# UIA driver folder (used as WorkingDirectory when launching the UIA server)
$uiaDriverFolder        = Join-Paths @($driversFolder, "uia-driver-server")

# ---------------------------------------------------------------------------
# Start Selenium Hub
#
# Notes/Behavior:
#   - Hub runs as a background process
#   - session-request-timeout is set very high for long-running workflows
# ---------------------------------------------------------------------------
Write-Host "Starting Selenium Hub (session timeout ~42300 seconds)..."

Start-Process `
    -FilePath         $javaExecutable `
    -ArgumentList     "-jar $($seleniumExecutable) hub --session-request-timeout 42300" `
    -WorkingDirectory $binariesFolder

# ---------------------------------------------------------------------------
# Windows-only: start UIA Driver server and register UIA node
#
# Notes/Behavior:
#   - UIA is Windows-specific, so we guard it with OS detection
#   - The UIA node is registered to the Hub using a TOML config
# ---------------------------------------------------------------------------
if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {

    Write-Host "Starting UIA Driver (Windows-specific)..."

    # Launch the UIA DriverServer (dotnet <dll>) from its own folder.
    # WorkingDirectory matters if the server loads config/files relative to itself.
    Start-Process `
        -FilePath         $dotnetExecutable `
        -ArgumentList     $uiaDriverExecutable `
        -WorkingDirectory $uiaDriverFolder

    Write-Host "Registering UIA Node on port 5554..."

    # Register UIA node with the Hub (TOML defines capabilities, etc.).
    Start-Process `
        -FilePath         $javaExecutable `
        -ArgumentList     "-jar $($seleniumExecutable) node --hub $($HubUri) --config $(Join-Paths -Paths @($configurationsFolder, 'uia-node.toml')) --port 5554" `
        -WorkingDirectory $binariesFolder
}

# ---------------------------------------------------------------------------
# Start ChromeDriver
#
# Notes/Behavior:
#   - ChromeDriver is launched explicitly on port 9513
#   - This script assumes chromedriver is in drivers\chrome\
# ---------------------------------------------------------------------------
Write-Host "Starting ChromeDriver on port 9513..."

Start-Process `
    -FilePath         $chromeDriverExecutable `
    -ArgumentList     "--port=9513" `
    -WorkingDirectory $driversFolder

# ---------------------------------------------------------------------------
# Register Chrome node
#
# Notes/Behavior:
#   - Node config comes from chrome-node.toml
#   - Node port is set to 5552
# ---------------------------------------------------------------------------
Write-Host "Registering Chrome Node on port 5552..."

Start-Process `
    -FilePath         $javaExecutable `
    -ArgumentList     "-jar $($seleniumExecutable) node --hub $($HubUri) --config $(Join-Paths -Paths @($configurationsFolder, 'chrome-node.toml')) --port 5552" `
    -WorkingDirectory $binariesFolder
