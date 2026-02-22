<#
-------------------------------------------------------------------------------
Script:     Start-SeleniumHub.ps1 (example)
Purpose:    Starts a portable Selenium Grid Hub using the bundled Java runtime.
Description:
    This script resolves the Java runtime and Selenium server JAR relative to
    the script location, then launches the Selenium Hub with a configurable
    session request timeout.

    Intended for portable/offline sandbox deployments.

Compatibility:
    - PowerShell 5.1+
    - Windows/Linux supported
    - Requires bundled Java runtime and selenium-server.jar

Assumptions:
    - Java exists at: ..\runtime\jdk\bin\java
    - Selenium server exists at: ..\selenium-grid\selenium-server.jar
-------------------------------------------------------------------------------
#>

[CmdletBinding()]
param (
    # Maximum time (in seconds) the Hub waits for a session request.
    # Default (~11.75 hours) is tuned for long-running automation scenarios.
    [int]$SessionRequestTimeout = 42300
)

function Join-Paths {
    <#
    ---------------------------------------------------------------------------
    Function:   Join-Paths
    Purpose:    Joins multiple path segments into a single path safely.
    Description:
        PowerShell's Join-Path joins only two segments at a time. This helper
        accepts an array and joins them iteratively.

    Notes/Behavior:
        - Platform-safe path handling
        - Avoids manual string concatenation
        - Designed for portable scripts
    ---------------------------------------------------------------------------
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    # Initialize with the first segment.
    $result = $Paths[0]

    # Iteratively join remaining segments.
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
# Resolve required folders (alphabetically sorted)
# ---------------------------------------------------------------------------
$binariesFolder = Join-Paths @($baseFolder, "..", "selenium-grid")
$javaFolder     = Join-Paths @($baseFolder, "..", "runtime", "jdk")

# ---------------------------------------------------------------------------
# Resolve executables/artifacts
#
# Notes/Behavior:
#   - No extension appended automatically (portable-friendly)
#   - Ensure files exist in the sandbox layout
# ---------------------------------------------------------------------------
$javaExecutable     = Join-Paths @($javaFolder, "bin", "java")
$seleniumExecutable = Join-Paths @($binariesFolder, "selenium-server.jar")

# ---------------------------------------------------------------------------
# Start Selenium Hub
#
# Notes/Behavior:
#   - Runs in background via Start-Process
#   - Uses extended session timeout for long automation runs
#   - Working directory set to selenium-grid folder
# ---------------------------------------------------------------------------
Write-Host "Starting Selenium Hub (session timeout ~$SessionRequestTimeout seconds)..."

Start-Process `
    -FilePath         $javaExecutable `
    -ArgumentList     "-jar $($seleniumExecutable) hub --session-request-timeout $($SessionRequestTimeout)" `
    -WorkingDirectory $binariesFolder
