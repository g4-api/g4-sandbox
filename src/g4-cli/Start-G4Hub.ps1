<#
-------------------------------------------------------------------------------
Script:     Start-G4Hub.ps1 (example)
Purpose:    Launches G4 Hub using a bundled .NET runtime and environment
            variables loaded from a local .env file.
Description:
    This script is meant for portable/offline sandbox deployments. It:
      1) Loads environment variables from a .env file into a hashtable
      2) Resolves runtime/app paths relative to the script location
      3) Starts G4 Hub (a .NET app) with those environment variables injected
         into the process environment (without polluting the current session)

Compatibility:
    - PowerShell 5.1+
    - Works on Windows/Linux (path building is platform-safe)
    - Requires a bundled dotnet runtime folder and the Hub DLL

Assumptions:
    - .env is located at: <scriptFolder>\..\ .env
    - dotnet runtime exists at: <scriptFolder>\..\runtime\dotnet\dotnet
    - G4 Hub DLL exists at: <scriptFolder>\..\g4-hub\G4.Services.Hub.dll
-------------------------------------------------------------------------------
#>

function Import-EnvironmentVariablesFile {
    <#
    ---------------------------------------------------------------------------
    Function:   Import-EnvironmentVariablesFile
    Purpose:    Loads KEY=VALUE pairs from a .env file into a hashtable.
    Description:
        Reads a file line-by-line and parses environment variables formatted as:
            KEY=VALUE

        Comments and empty lines are ignored.

    Notes/Behavior:
        - Does not expand variables (e.g. ${HOME}) - values are taken as-is.
        - Does not strip quotes; if your .env contains quotes, they remain.
        - Only splits on the first '=' so values may contain '='.
        - Returns $null if the file does not exist (caller can decide behavior).
    ---------------------------------------------------------------------------
    #>
    [CmdletBinding()]
    param(
        # Path to a .env-style file. Defaults to ".env" in the current directory.
        [Parameter(Mandatory = $false)]
        [string]$EnvironmentFilePath = ".env"
    )

    # Will hold parsed environment variables as KEY -> VALUE.
    $environmentDictionary = @{}

    # Fail fast if file does not exist.
    if (-Not (Test-Path $EnvironmentFilePath)) {
        Write-Warning "The environment file was not found at path: $($EnvironmentFilePath)"
        return $null
    }

    # Read file content line-by-line to preserve simple parsing rules.
    Get-Content $EnvironmentFilePath | ForEach-Object {

        # Skip comments and empty lines.
        $line = $_
        if ($line.Trim().StartsWith("#") -or [string]::IsNullOrWhiteSpace($line)) {
            return
        }

        # Split the line on the FIRST '=' only.
        # This allows values like: CONNECTION_STRING=Server=...;Database=...
        $parts = $line.Split('=', 2)
        if ($parts.Length -ne 2) {
            return
        }

        # Normalize key/value by trimming whitespace.
        $key   = $parts[0].Trim()
        $value = $parts[1].Trim()

        # Store in hashtable (later keys overwrite earlier keys).
        $environmentDictionary[$key] = $value

        # Verbose log for troubleshooting (enable via: -Verbose)
        Write-Verbose "Loaded environment variable '$($key)' with value '$($value)'"
    }

    return $environmentDictionary
}

function Join-Paths {
    <#
    ---------------------------------------------------------------------------
    Function:   Join-Paths
    Purpose:    Joins multiple path segments into one path safely.
    Description:
        PowerShell's Join-Path joins only two segments at a time.
        This helper accepts an array of segments and joins them iteratively.

    Notes/Behavior:
        - Preserves platform-specific separators.
        - Avoids brittle string concatenation.
    ---------------------------------------------------------------------------
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    # Start with first element as the "root" of the combined path.
    $result = $Paths[0]

    # Join remaining segments one by one.
    for ($i = 1; $i -lt $Paths.Length; $i++) {
        $result = Join-Path -Path $result -ChildPath $Paths[$i]
    }

    return $result
}

function Start-ProcessWithEnvironment {
    <#
    ---------------------------------------------------------------------------
    Function:   Start-ProcessWithEnvironment
    Purpose:    Starts a process with custom environment variables.
    Description:
        Uses System.Diagnostics.ProcessStartInfo so we can inject environment
        variables into the *child process* without changing the current
        PowerShell session environment.

    Notes/Behavior:
        - UseShellExecute=$false is REQUIRED to set environment variables.
        - Returns a System.Diagnostics.Process instance (can be monitored).
        - Does not wait for exit; caller can use .WaitForExit() if needed.
    ---------------------------------------------------------------------------
    #>
    [CmdletBinding()]
    param(
        # Executable to run (e.g., dotnet)
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        # Raw argument string passed as-is to the process
        [Parameter(Mandatory = $false)]
        [string]$ArgumentsList,

        # Optional working directory for the process
        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory,

        # Optional environment variables to inject (KEY -> VALUE)
        [Parameter(Mandatory = $false)]
        [hashtable]$EnvironmentVariables
    )

    # Create a ProcessStartInfo so we can control environment + working dir.
    $processStartInformation = New-Object System.Diagnostics.ProcessStartInfo

    # The executable path (e.g., bundled dotnet).
    $processStartInformation.FileName = $FilePath

    # Only set arguments when supplied (avoids passing empty string).
    if ($ArgumentsList) {
        $processStartInformation.Arguments = $ArgumentsList
    }

    # Working directory (important for resolving relative files/config/logging).
    if ($WorkingDirectory) {
        $processStartInformation.WorkingDirectory = $WorkingDirectory
    }

    # Required to allow environment variable injection.
    $processStartInformation.UseShellExecute = $false

    # Inject provided environment variables into the child process.
    if ($EnvironmentVariables) {
        foreach ($key in $EnvironmentVariables.Keys) {

            # Overwrite/add variable for the child process.
            $processStartInformation.EnvironmentVariables[$key] = $EnvironmentVariables[$key]
        }
    }

    # Start the process and return the Process object.
    return [System.Diagnostics.Process]::Start($processStartInformation)
}

# ---------------------------------------------------------------------------
# Resolve base directory (directory containing this script)
# ---------------------------------------------------------------------------
$baseFolder = $PSScriptRoot

# ---------------------------------------------------------------------------
# Load environment variables from a .env file located next to the sandbox root
# (scriptFolder\..\ .env)
# ---------------------------------------------------------------------------
$environmentVariables = Import-EnvironmentVariablesFile `
    -EnvironmentFilePath (Join-Paths @($baseFolder, "..", ".env"))

# ---------------------------------------------------------------------------
# Resolve portable folders (alphabetical for readability)
# ---------------------------------------------------------------------------
$dotnetFolder = Join-Paths @($baseFolder, "..", "runtime", "dotnet")
$g4HubFolder  = Join-Paths @($baseFolder, "..", "g4-hub")

# ---------------------------------------------------------------------------
# Resolve executables
# ---------------------------------------------------------------------------
$dotnetExecutable = Join-Paths @($dotnetFolder, "dotnet")
$g4HubExecutable  = Join-Paths @($g4HubFolder, "G4.Services.Hub.dll")

# ---------------------------------------------------------------------------
# Launch G4 Hub
#
# Notes/Behavior:
#   - Runs: <dotnet> <hubDll>
#   - Working directory set to Hub folder (important for appsettings, logs, etc.)
#   - Environment variables are injected only into this process
# ---------------------------------------------------------------------------
Write-Host "Starting G4 Hub..."

Start-ProcessWithEnvironment `
    -FilePath             $dotnetExecutable `
    -ArgumentsList        $g4HubExecutable `
    -WorkingDirectory     $g4HubFolder `
    -EnvironmentVariables $environmentVariables
