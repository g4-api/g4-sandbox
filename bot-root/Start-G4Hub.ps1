function Import-EnvironmentVariablesFile {
    <#
    .SYNOPSIS
        Imports environment variables from an environment file into a dictionary.

    .DESCRIPTION
        This function reads an environment file (with each line in the format KEY=value),
        splits each line on the first "=" occurrence (allowing values to contain additional "=" characters),
        and returns a hashtable containing the key-value pairs.

    .PARAMETER EnvironmentFilePath
        The full path to the environment file. Defaults to ".env" if not specified.

    .EXAMPLE
        $environmentDictionary = Import-EnvironmentVariablesFile -EnvironmentFilePath ".\config\environment.env"
        Returns a dictionary of environment variables from the specified file.

    .EXAMPLE
        $environmentDictionary = Import-EnvironmentVariablesFile
        Returns a dictionary of environment variables from a file named .env in the current directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$EnvironmentFilePath = ".env"
    )

    $environmentDictionary = @{}

    if (-Not (Test-Path $EnvironmentFilePath)) {
        Write-Warning "The environment file was not found at path: $EnvironmentFilePath"
        return $null
    }

    Get-Content $EnvironmentFilePath | ForEach-Object {
        # Skip comments and empty lines.
        if ($_.Trim().StartsWith("#") -or [string]::IsNullOrWhiteSpace($_)) {
            return
        }

        # Split the line on the first '=' occurrence.
        $parts = $_.Split('=', 2)
        if ($parts.Length -ne 2) {
            return
        }
        
        $key   = $parts[0].Trim()
        $value = $parts[1].Trim()
        
        $environmentDictionary[$key] = $value
        Write-Verbose "Loaded environment variable '$key' with value '$value'"
    }

    return $environmentDictionary
}

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

function Start-ProcessWithEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [string]$ArgumentsList,
        
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$EnvironmentVariables
    )
    
    # Create a new process start information object.
    $processStartInformation = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInformation.FileName = $FilePath
    
    if ($ArgumentsList) {
        $processStartInformation.Arguments = $ArgumentsList
    }
    
    if ($WorkingDirectory) {
        $processStartInformation.WorkingDirectory = $WorkingDirectory
    }

    # Set UseShellExecute to false to enable environment variables.
    $processStartInformation.UseShellExecute = $false
    
    # Set environment variables if provided.
    if ($EnvironmentVariables) {
        foreach ($key in $EnvironmentVariables.Keys) {
            $processStartInformation.EnvironmentVariables[$key] = $EnvironmentVariables[$key]
        }
    }
    
    # Start the process and return the process object.
    return [System.Diagnostics.Process]::Start($processStartInformation)
}

# Determine if the OS platform is Linux
$isLinuxOs = $false
if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Unix) {
    $isLinuxOs = $true
}

# Define base directory (the directory containing the script)
$baseFolder = $PSScriptRoot

# Import environment variables from the .env file located in the base folder.
$environmentVariables = Import-EnvironmentVariablesFile -EnvironmentFilePath (Join-Paths $baseFolder, ".env")  

# Define default folder names (alphabetically sorted)
$dotnetFolder = Join-Paths @($baseFolder, "..", "runtime", "dotnet-windows")
$g4HubFolder  = Join-Paths @($baseFolder, "g4-hub")

# If the script is running on a Linux machine, replace "-Windows" with "-linux" in relevant folders
if ($isLinuxOs) {
    $dotnetFolder  = $dotnetFolder  -replace "-Windows", "-linux"
}

# Build the path to the dotnet executable (dotnet[.exe] or similar) and other executables
$dotnetExecutable = Join-Paths @($dotnetFolder, "dotnet")
$g4HubExecutable  = Join-Paths @($g4HubFolder, "G4.Services.Hub.dll")

# ---------------------------------------------------------
Write-Host "Starting G4 Hub..."
Start-ProcessWithEnvironment `
    -FilePath             $dotnetExecutable `
    -ArgumentsList        $g4HubExecutable `
    -WorkingDirectory     $g4HubFolder `
    -EnvironmentVariables $environmentVariables
