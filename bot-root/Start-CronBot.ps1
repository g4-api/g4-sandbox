<#
.SYNOPSIS
    Reads an 'automation.json' file, sends its Base64-encoded contents to a remote endpoint,
    and saves the response along with any errors.

.DESCRIPTION
    This script performs the following actions:
    1. Searches for a subfolder named after $BotName within the specified $BotVolume.
    2. Locates the 'automation.json' file within the "bot" subdirectory of the bot folder.
    3. Reads the file, converts its content to JSON, updates the 'driverBinaries' property,
       converts the JSON back to a string, and encodes the string in Base64.
    4. Sends the Base64-encoded string via a POST request to the remote endpoint at $HubUri,
       appending the '/api/v4/g4/automation/base64/invoke' path.
    5. Saves the JSON response in an 'output' directory with a timestamped filename.
    6. Records any errors in an 'errors' directory.
    Note: This script executes once and does not loop indefinitely.

.NOTES
    - Designed for demonstration and automation testing.
    - Requires PowerShell 5.1+ (or higher).

.PARAMETER BotVolume
    The main folder path where the bot's subfolder resides.

.PARAMETER BotName
    The name of the bot's subfolder. This folder should contain a "bot" subdirectory that includes 'automation.json'.

.PARAMETER CronSchedules
    The comma-separated cron schedules used for scheduling the automation jobs.

.PARAMETER DriverBinaries
    The URL to the driver binaries that will be inserted into the automation JSON.

.PARAMETER HubUri
    The base URI of the remote service (e.g., http://host.docker.internal:9944).

.PARAMETER Token
    The authentication token required for the bot's operation.
    This token is injected into the automation JSON's 'authentication.token' property,
    enabling the bot to run, and is also passed to the Docker container if running in Docker mode.

.PARAMETER Docker
    Switch to run the script inside a Docker container environment.

.EXAMPLE
    .\LoopScript.ps1 -BotVolume "E:\Garbage\bot-volume" -BotName "demo-bot" -CronSchedules "*/5 * * * *,30 8 * * *,0 18 * * *" -DriverBinaries "http://host.docker.internal:4444/wd/hub" -HubUri "http://host.docker.internal:9944" -Docker
#>
param (
    [CmdletBinding()]
    [Parameter(Mandatory = $true)] [string]$BotVolume,
    [Parameter(Mandatory = $true)] [string]$BotName,
    [Parameter(Mandatory = $false)][string]$CronSchedules='* * * * *',
    [Parameter(Mandatory = $true)] [string]$DriverBinaries,
    [Parameter(Mandatory = $true)] [string]$HubUri,
    [Parameter(Mandatory = $true)] [string]$Token,
    [Parameter(Mandatory = $false)][switch]$Docker
)

function Import-EnvironmentVariablesFile {
    <#
    .SYNOPSIS
        Imports environment variables from an environment file and additional parameters into the current session.

    .DESCRIPTION
        This function reads an environment file (each line formatted as KEY=value) and splits each line on the first "=".
        In addition, it accepts an array of additional environment variable strings (AdditionalEnvironmentVariables) in key=value format.
        Both sets of key-value pairs are imported into the current session's environment.
        Any keys specified in SkipNames are skipped.

    .PARAMETER EnvironmentFilePath
        The full path to the environment file. Defaults to ".env" in the script's directory.

    .PARAMETER SkipNames
        An array of environment variable names that should not be imported from the file or the additional parameters.

    .PARAMETER AdditionalEnvironmentVariables
        An array of additional environment variable strings in key=value format.
        
    .EXAMPLE
        Import-EnvironmentVariablesFile -EnvironmentFilePath ".\config\environment.env" -SkipNames "PATH","JAVA_HOME" `
            -AdditionalEnvironmentVariables @("MY_VAR=Value1", "OTHER_VAR=Value2")
    #>
    [CmdletBinding()]
    param(
        [string]  $EnvironmentFilePath            = (Join-Path $PSScriptRoot ".env"),
        [string[]]$SkipNames                      = @(),
        [string[]]$AdditionalEnvironmentVariables = @()
    )

    Write-Verbose "Check if the environment file exists; if not, display a message and exit"
    if (-Not (Test-Path $EnvironmentFilePath)) {
        Write-Warning "The environment file was not found at path: $($EnvironmentFilePath)"
        return
    }

    Write-Verbose "Read the environment file line by line"
    $parametersCollection = (Get-Content $EnvironmentFilePath -Force -Encoding UTF8) + $AdditionalEnvironmentVariables
    $parametersCollection | ForEach-Object {
        Write-Verbose "Skip lines that are comments (starting with '#') or empty after trimming whitespace"
        if ($_.Trim().StartsWith("#") -or [string]::IsNullOrWhiteSpace($_)) {
            return
        }

        Write-Verbose "Split the line into two parts at the first '=' occurrence"
        $parts = $_.Split('=', 2)
        
        Write-Verbose "If the line does not contain exactly two parts, skip it"
        if ($parts.Length -ne 2) {
            return
        }
        
        Write-Verbose "Trim any leading or trailing whitespace from the key and value"
        $key   = $parts[0].Trim()
        $value = $parts[1].Trim()

        # Skip this key if it is in the skip list.
        if ($SkipNames -contains $key) {
            Write-Verbose "Skipping environment variable '$($key)' as it is in the skip list"
            return
        }
        
        Set-Item -Path "Env:$($key)" -Value $value
        Write-Verbose "Set environment variable '$($key)' with value '$($value)'"
    }
}

# If the Docker switch is provided, attempt to start the Docker container and exit.
if ($Docker) {
    try {
        Write-Verbose "Docker switch is enabled. Preparing to launch Docker container for bot '$($BotName)'."
        Write-Verbose "Building the Docker command from the specified parameters."
        $cmdLines = @(
            "run -d -v `"$($BotVolume):/bots`"",
            " -e BOT_NAME=`"$($BotName)`"",
            " -e CRON_SCHEDULES=`"$($CronSchedules)`"",
            " -e DRIVER_BINARIES=`"$($DriverBinaries)`"",
            " -e HUB_URI=`"$($HubUri)`"",
            " -e TOKEN=`"$($Token)`"",
            " --name `"$($BotName)-$([guid]::NewGuid())`" g4-cron-bot:latest"
        )

        Write-Verbose "Joining command parts into a single Docker command string."
        $dockerCmd = $cmdLines -join [string]::Empty

        Write-Host "Invoking Docker with the following command:$([System.Environment]::NewLine)docker $($dockerCmd)"
        $process = Start-Process -FilePath "docker" -ArgumentList $dockerCmd -PassThru
        $process.WaitForExit(60000)
        
        Write-Verbose "Docker container '$($BotName)' started successfully."
        Exit 0
    }
    catch {
        Write-Error "Failed to start Docker container '$($BotName)': $($_.Exception.GetBaseException())"
        Exit 1
    }
}

try {
    Write-Verbose "Setting Environment Parameters"
    Import-EnvironmentVariablesFile  
}
catch {
    Write-Error "Failed to set environment parameters: $($_.Exception.GetBaseException().Message)"
}

# Build the final request URL by removing any trailing slash from $HubUri and appending the endpoint path.
$requestUri = "$($HubUri.TrimEnd('/'))/api/v4/g4/automation/base64/invoke"

# Construct the full path to the output directory where responses will be saved.
$outputDirectory = [System.IO.Path]::Combine($BotVolume, $BotName, "output")

Clear-Host
Write-Host
Write-Host "Starting bot process.$([System.Environment]::NewLine)Press [Ctrl] + [C] to stop the script."

# Build the full path to the bot's automation file:
# 1. Combine $BotVolume and $BotName to create the bot directory.
# 2. Append "bot" to form the bot automation directory.
# 3. Join "automation.json" to construct the complete file path.
$botDirectory           = Join-Path $BotVolume $BotName
$botAutomationDirectory = Join-Path $botDirectory "bot"
$botFilePath            = Join-Path $botAutomationDirectory "automation.json"

try {
    # Check if the 'automation.json' file exists in the bot automation directory.
    if (-Not (Test-Path $botFilePath)) {
        Write-Warning "File 'automation.json' not found in '$botAutomationDirectory'. Waiting for next interval."
        exit 0
    }

    # Generate a unique session timestamp for file naming and session identification.
    $session = (Get-Date).ToString("yyyyMMddHHmmssfff")
    
    # Create the output file path using the session timestamp.
    $outputFilePath = [System.IO.Path]::Combine($outputDirectory, "$($BotName)-$($session).json")
    
    # Create the error file path (inside an 'errors' folder) using the session timestamp.
    $errorsPath = [System.IO.Path]::Combine($BotVolume, $BotName, "errors", "$($BotName)-$($session).json")
    
    # Read the entire content of 'automation.json' as raw text.
    $botFileContent = [System.IO.File]::ReadAllText($botFilePath, [System.Text.Encoding]::UTF8)

    # Convert the JSON text to an object to update the 'driverBinaries' property.
    $botFileJson = ConvertFrom-Json $botFileContent

    # Update the 'driverBinaries' property within the driverParameters object.
    $botFileJson.driverParameters.driverBinaries = $DriverBinaries

    # Update the 'token' property within the authentication object.
    $botFileJson.authentication.token = $Token

    # Convert the modified JSON object back to a JSON string with sufficient depth.
    $botFileContent = ConvertTo-Json $botFileJson -Depth 50 -Compress

    # Convert the updated JSON text to a byte array and encode it in Base64.
    $botBytes = [System.Text.Encoding]::UTF8.GetBytes($botFileContent)
    $botContent = [System.Convert]::ToBase64String($botBytes)

    # Send the Base64-encoded string via a POST request to the remote endpoint.
    # The timestamp in ISO 8601 format is prepended to the message.
    Write-Verbose "$(Get-Date -Format o): Sending Base64-encoded 'automation.json' to remote endpoint..."
    $response = Invoke-RestMethod -Uri $requestUri -Method Post -Body $botContent -ContentType "text/plain"
}
catch {
    # If an error occurs, display a message and log the error details to the designated errors file.
    $baseException = $_.Exception.GetBaseException()
    Write-Error "An error occurred '$($baseException.Message)'.$([System.Environment]::NewLine)Check $errorsPath for details."
    @{ error = $baseException.StackTrace; message = $baseException.Message } | ConvertTo-Json -Compress | Out-File -FilePath $errorsPath -Force -ErrorAction Continue
}
finally {
    try {
        if($null -ne $outputFilePath -and $response) {
            $response | ConvertTo-Json -Depth 30 -Compress -ErrorAction Continue | Out-File -FilePath $outputFilePath -Force -ErrorAction Continue
            Write-Verbose "Response successfully saved to: $outputFilePath"
        }
    }
    catch {
        Write-Error "Failed to save response to: $outputFilePath. Error details: $($_.Exception.GetBaseException().Message)"
    }
}
