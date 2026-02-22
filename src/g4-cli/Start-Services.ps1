<#
-------------------------------------------------------------------------------
Script:     Start-G4Sandbox.ps1 (example)
Purpose:    Boots a full local sandbox:
            - Selenium Grid Hub
            - ChromeDriver + Chrome Node registration
            - (Windows only) UIA Driver + UIA Node registration
            - G4 Hub (.NET) with environment variables from .env

Description:
    This script is designed for a portable/offline sandbox layout. It resolves
    all required paths relative to the script directory, then starts the
    required processes using bundled runtimes (Java/.NET) and driver binaries.

    Environment variables from a local .env file are injected into the G4 Hub
    process only (without modifying the current PowerShell session).

Compatibility:
    - PowerShell 5.1+
    - Windows/Linux supported (UIA branch runs only on Windows)

Assumptions:
    - Folder structure is preserved relative to the script file
    - Bundled Java exists at:       ..\runtime\jdk\bin\java
    - Bundled dotnet exists at:     ..\runtime\dotnet\dotnet
    - Selenium server exists at:    ..\selenium-grid\selenium-server.jar
    - Selenium configs exist at:    ..\selenium-grid\configurations\*.toml
    - ChromeDriver exists at:       ..\drivers\chrome\chromedriver
    - UIA Driver exists at:         ..\drivers\uia-driver-server\Uia.DriverServer.dll (Windows only)
    - G4 Hub exists at:             ..\g4-hub\G4.Services.Hub.dll
    - .env exists at:               ..\.env (optional; warning if missing)
-------------------------------------------------------------------------------
#>

param(
    # Selenium Hub endpoint that nodes should register against.
    # Note: Hub is started locally by this script; this is used for node registration.
    [string]$HubUri = "http://localhost:4444/wd/hub"
)

function Import-EnvironmentVariablesFile {
    <#
    ---------------------------------------------------------------------------
    Function:   Import-EnvironmentVariablesFile
    Purpose:    Loads KEY=VALUE pairs from a .env file into a hashtable.
    Description:
        Reads a .env-style file and parses lines formatted as:
            KEY=VALUE

        Ignores:
          - Empty lines
          - Comment lines starting with '#'

    Notes/Behavior:
        - Splits only on the first '=' so values may contain '=' characters.
        - Values are loaded "as-is" (no quote stripping, no variable expansion).
        - Returns $null when file does not exist (caller can decide behavior).
    ---------------------------------------------------------------------------
    #>
    [CmdletBinding()]
    param(
        # Path to the environment file (.env)
        [Parameter(Mandatory = $false)]
        [string]$EnvironmentFilePath = ".env"
    )

    # Hashtable holding KEY -> VALUE entries
    $environmentDictionary = @{}

    # If the file does not exist, warn and return null (script continues)
    if (-Not (Test-Path $EnvironmentFilePath)) {
        Write-Warning "The environment file was not found at path: $($EnvironmentFilePath)"
        return $null
    }

    # Parse file line-by-line
    Get-Content $EnvironmentFilePath | ForEach-Object {

        # Skip comments and empty lines
        $line = $_
        if ($line.Trim().StartsWith("#") -or [string]::IsNullOrWhiteSpace($line)) {
            return
        }

        # Split on first '=' only (allows values to contain '=')
        $parts = $line.Split('=', 2)
        if ($parts.Length -ne 2) {
            return
        }

        # Normalize key/value by trimming whitespace
        $key   = $parts[0].Trim()
        $value = $parts[1].Trim()

        # Store/overwrite the variable
        $environmentDictionary[$key] = $value

        # Verbose logging (enable via: -Verbose)
        Write-Verbose "Loaded environment variable '$($key)' with value '$($value)'"
    }

    return $environmentDictionary
}

function Join-Paths {
    <#
    ---------------------------------------------------------------------------
    Function:   Join-Paths
    Purpose:    Joins multiple path segments into a single path safely.
    Description:
        PowerShell's Join-Path joins two segments at a time. This helper accepts
        an array of segments and joins them iteratively.

    Notes/Behavior:
        - Platform-safe (Windows/Linux separators)
        - Avoids string concatenation pitfalls
    ---------------------------------------------------------------------------
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    # Start with first element as the base/root
    $result = $Paths[0]

    # Join remaining segments one-by-one
    for ($i = 1; $i -lt $Paths.Length; $i++) {
        $result = Join-Path -Path $result -ChildPath $Paths[$i]
    }

    return $result
}

function Start-ProcessWithEnvironment {
    <#
    ---------------------------------------------------------------------------
    Function:   Start-ProcessWithEnvironment
    Purpose:    Starts a process while injecting environment variables.
    Description:
        Uses System.Diagnostics.ProcessStartInfo so environment variables apply
        only to the child process, without mutating the current session.

    Notes/Behavior:
        - UseShellExecute must be $false to set environment variables.
        - Returns a System.Diagnostics.Process instance.
        - Does not wait for process exit.
    ---------------------------------------------------------------------------
    #>
    [CmdletBinding()]
    param(
        # Executable to run (e.g. dotnet)
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        # Raw argument string passed to the process (e.g. "<dll path>")
        [Parameter(Mandatory = $false)]
        [string]$ArgumentsList,

        # Optional working directory for the process
        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory,

        # Environment variables to inject (KEY -> VALUE)
        [Parameter(Mandatory = $false)]
        [hashtable]$EnvironmentVariables
    )

    # Configure process start parameters
    $processStartInformation = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInformation.FileName = $FilePath

    # Set arguments only when provided
    if ($ArgumentsList) {
        $processStartInformation.Arguments = $ArgumentsList
    }

    # Set working directory when provided
    if ($WorkingDirectory) {
        $processStartInformation.WorkingDirectory = $WorkingDirectory
    }

    # Required for environment variable injection
    $processStartInformation.UseShellExecute = $false

    # Inject environment variables (if provided)
    if ($EnvironmentVariables) {
        foreach ($key in $EnvironmentVariables.Keys) {
            $processStartInformation.EnvironmentVariables[$key] = $EnvironmentVariables[$key]
        }
    }

    # Start and return the process
    return [System.Diagnostics.Process]::Start($processStartInformation)
}

# ---------------------------------------------------------------------------
# Resolve base directory (directory containing this script)
# ---------------------------------------------------------------------------
$baseFolder = $PSScriptRoot

# ---------------------------------------------------------------------------
# Load environment variables from: <scriptFolder>\..\ .env
#
# Notes/Behavior:
#   - Missing .env is not fatal (function returns $null and script continues)
# ---------------------------------------------------------------------------
$environmentVariables = Import-EnvironmentVariablesFile `
    -EnvironmentFilePath (Join-Paths @($baseFolder, "..", ".env"))

# ---------------------------------------------------------------------------
# Resolve sandbox folders (alphabetically sorted)
# ---------------------------------------------------------------------------
$binariesFolder       = Join-Paths @($baseFolder, "..", "selenium-grid")
$configurationsFolder = Join-Paths @($baseFolder, "..", "selenium-grid", "configurations")
$dotnetFolder         = Join-Paths @($baseFolder, "..", "runtime", "dotnet")
$driversFolder        = Join-Paths @($baseFolder, "..", "drivers")
$g4HubFolder          = Join-Paths @($baseFolder, "..", "g4-hub")
$javaFolder           = Join-Paths @($baseFolder, "..", "runtime", "jdk")

# ---------------------------------------------------------------------------
# Resolve executables/artifacts
# ---------------------------------------------------------------------------
$chromeDriverExecutable = Join-Paths @($driversFolder, "chrome", "chromedriver")
$dotnetExecutable       = Join-Paths @($dotnetFolder, "dotnet")
$g4HubExecutable        = Join-Paths @($g4HubFolder, "G4.Services.Hub.dll")
$javaExecutable         = Join-Paths @($javaFolder, "bin", "java")
$seleniumExecutable     = Join-Paths @($binariesFolder, "selenium-server.jar")
$uiaDriverExecutable    = Join-Paths @($driversFolder, "uia-driver-server", "Uia.DriverServer.dll")

# UIA driver working directory (used only on Windows)
$uiaDriverFolder        = Join-Paths @($driversFolder, "uia-driver-server")

# ---------------------------------------------------------------------------
# Start Selenium Hub
#
# Notes/Behavior:
#   - session-request-timeout is intentionally high for long automation runs
#   - Hub will listen on its default port (4444) unless configured otherwise
# ---------------------------------------------------------------------------
Write-Host "Starting Selenium Hub (session timeout ~42300 seconds)..."

Start-Process `
    -FilePath         $javaExecutable `
    -ArgumentList     "-jar $($seleniumExecutable) hub --session-request-timeout 42300" `
    -WorkingDirectory $binariesFolder

# ---------------------------------------------------------------------------
# Windows-only: start UIA driver and register UIA node
# ---------------------------------------------------------------------------
if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {

    Write-Host "Starting UIA Driver (Windows-specific)..."

    # Launch UIA DriverServer using bundled dotnet runtime
    Start-Process `
        -FilePath         $dotnetExecutable `
        -ArgumentList     $uiaDriverExecutable `
        -WorkingDirectory $uiaDriverFolder

    Write-Host "Registering UIA Node on port 5554..."

    # Register UIA node with hub using TOML configuration
    Start-Process `
        -FilePath         $javaExecutable `
        -ArgumentList     "-jar $($seleniumExecutable) node --hub $($HubUri) --config $(Join-Paths -Paths @($configurationsFolder, 'uia-node.toml')) --port 5554" `
        -WorkingDirectory $binariesFolder
}

# ---------------------------------------------------------------------------
# Start ChromeDriver
# ---------------------------------------------------------------------------
Write-Host "Starting ChromeDriver on port 9513..."

Start-Process `
    -FilePath         $chromeDriverExecutable `
    -ArgumentList     "--port=9513" `
    -WorkingDirectory $driversFolder

# ---------------------------------------------------------------------------
# Register Chrome node
# ---------------------------------------------------------------------------
Write-Host "Registering Chrome Node on port 5552..."

Start-Process `
    -FilePath         $javaExecutable `
    -ArgumentList     "-jar $($seleniumExecutable) node --hub $($HubUri) --config $(Join-Paths -Paths @($configurationsFolder, 'chrome-node.toml')) --port 5552" `
    -WorkingDirectory $binariesFolder

# ---------------------------------------------------------------------------
# Start G4 Hub
#
# Notes/Behavior:
#   - Runs: dotnet <G4.Services.Hub.dll>
#   - Injects environment variables from .env into the process only
# ---------------------------------------------------------------------------
Write-Host "Starting G4 Hub..."

Start-ProcessWithEnvironment `
    -FilePath             $dotnetExecutable `
    -ArgumentsList        $g4HubExecutable `
    -WorkingDirectory     $g4HubFolder `
    -EnvironmentVariables $environmentVariables