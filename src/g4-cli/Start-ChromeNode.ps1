<#
-------------------------------------------------------------------------------
Function:   Selenium Chrome Node Bootstrap
Purpose:    Starts a local ChromeDriver instance and registers a Selenium
            Grid node using the packaged runtime and configuration.
Description:
    This script resolves all required runtime paths relative to the script
    location, then:

      1. Launches ChromeDriver on a fixed port (9513)
      2. Registers a Selenium node to the specified Hub
      3. Uses the bundled Java runtime and Selenium server JAR

    Designed for portable/offline sandbox deployments (G4-friendly).

Compatibility:
    - PowerShell 5.1+
    - Windows/Linux (path logic is platform-safe)
    - Requires valid driver + Java runtime in expected folders

Assumptions:
    - Folder structure relative to script is preserved
    - ChromeDriver binary is executable
    - Selenium server JAR exists
    - Hub is reachable
-------------------------------------------------------------------------------
#>

param(
    # Selenium Grid Hub endpoint to register against
    [string]$HubUri   = "http://localhost:4444/wd/hub",

    # Port exposed by this node
    [int]   $NodePort = 5552
)

function Join-Paths {
    <#
    ---------------------------------------------------------------------------
    Function:   Join-Paths
    Purpose:    Safely joins multiple path segments into a single path.
    Description:
        Wrapper around Join-Path that supports joining more than two segments
        in a clean and readable way.

        Example:
            Join-Paths @("c:\root", "folder", "file.txt")

    Notes/Behavior:
        - Preserves platform path separators
        - Avoids manual string concatenation
        - Safe for portable scripts
    ---------------------------------------------------------------------------
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    # Start with the first path element
    $result = $Paths[0]

    # Iteratively join remaining segments
    for ($i = 1; $i -lt $Paths.Length; $i++) {
        $result = Join-Path -Path $result -ChildPath $Paths[$i]
    }

    # Return the fully combined path
    return $result
}

# ---------------------------------------------------------------------------
# Resolve base directory (directory where this script resides)
# ---------------------------------------------------------------------------
$baseFolder = $PSScriptRoot

# ---------------------------------------------------------------------------
# Resolve important folders (kept alphabetically for maintainability)
# ---------------------------------------------------------------------------
$binariesFolder       = Join-Paths @($baseFolder, "..", "selenium-grid")
$configurationsFolder = Join-Paths @($baseFolder, "..", "selenium-grid", "configurations")
$driversFolder        = Join-Paths @($baseFolder, "..", "drivers")
$javaFolder           = Join-Paths @($baseFolder, "..", "runtime", "jdk")

# ---------------------------------------------------------------------------
# Resolve executable paths
#
# Notes/Behavior:
#   - Assumes portable layout
#   - No extension added automatically (supports cross-platform)
# ---------------------------------------------------------------------------
$chromeDriverExecutable = Join-Paths @($driversFolder, "chrome", "chromedriver")
$javaExecutable         = Join-Paths @($javaFolder, "bin", "java")
$seleniumExecutable     = Join-Paths @($binariesFolder, "selenium-server.jar")

# ---------------------------------------------------------------------------
# Start ChromeDriver service
#
# Notes/Behavior:
#   - Uses fixed port 9513 (intentional design choice)
#   - Runs as background process
#   - Working directory set for relative driver dependencies
# ---------------------------------------------------------------------------
Write-Host "Starting ChromeDriver on port 9513..."

Start-Process `
    -FilePath        $chromeDriverExecutable `
    -ArgumentList    "--port=9513" `
    -WorkingDirectory $driversFolder

# ---------------------------------------------------------------------------
# Register Selenium node with the Hub
#
# Notes/Behavior:
#   - Uses bundled Java runtime
#   - Uses TOML node configuration
#   - Port is configurable via parameter
# ---------------------------------------------------------------------------
Write-Host "Registering Chrome Node on port $NodePort..."

Start-Process `
    -FilePath $javaExecutable `
    -ArgumentList "-jar $($seleniumExecutable) node --hub $($HubUri) --config $(Join-Paths -Paths @($configurationsFolder, 'chrome-node.toml')) --port $($NodePort)" `
    -WorkingDirectory $binariesFolder
