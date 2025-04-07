<#
.SYNOPSIS
    Automation script to process bot configuration and invoke a remote automation endpoint.

.DESCRIPTION
    This script manages bot automation by reading an 'automation.json' configuration file,
    updating its contents with the latest input file data, and sending a Base64-encoded version
    of the JSON to a remote endpoint. It also supports running inside a Docker container if
    the -Docker switch is specified.

.PARAMETER BotVolume
    Specifies the base directory path where the bot's files (input, archive, output, errors) are stored.
    
.PARAMETER BotName
    Specifies the name of the bot. This is used to construct file paths and as part of the Docker container name.
    
.PARAMETER DriverBinaries
    Specifies the path to the driver binaries used by the bot.
    
.PARAMETER HubUri
    Specifies the URI of the hub endpoint to which the automation JSON will be sent.
    
.PARAMETER IntervalTime
    Specifies the time interval, in seconds, to wait between each bot invocation.
    
.PARAMETER Token
    Specifies the authentication token used in the configuration.
    
.PARAMETER Docker
    A switch parameter. When specified, the script runs the bot inside a Docker container.
    
.EXAMPLE
    .\Start-ListenerBot.ps1 -BotVolume "C:\Bots" -BotName "MyBot" -DriverBinaries "C:\Drivers" -HubUri "https://hub.example.com" -IntervalTime "10" -Token "abc123"
#>
param (
    [CmdletBinding()]
    [Parameter(Mandatory = $true)] [string]$BotVolume,
    [Parameter(Mandatory = $true)] [string]$BotName,
    [Parameter(Mandatory = $true)] [string]$DriverBinaries,
    [Parameter(Mandatory = $true)] [string]$HubUri,
    [Parameter(Mandatory = $true)] [string]$IntervalTime,
    [Parameter(Mandatory = $true)] [string]$Token,
    [Parameter(Mandatory = $false)][switch]$Docker
)

function Get-NextFile {
    <#
    .SYNOPSIS
        Processes the most recent CSV or JSON file from an input folder, converts CSV files to minified JSON if needed,
        archives the processed file, and returns the resulting minified JSON content.

    .DESCRIPTION
        This function searches the specified InputDirectory for files with a .csv or .json extension and selects the most
        recent file based on LastWriteTime. If the file is a CSV, its content is imported and converted to a minified JSON
        string. If the file is JSON, the content is read and validated by converting it to an object, then reserialized as
        a minified JSON string. In both cases, if the JSON output is not an array, it is wrapped in an array format.
        Regardless of processing success, the file is archived to ArchiveDirectory. The archived file name includes a
        Session identifier to help track or differentiate processed files.
        
        The function returns a custom object containing:
          - StatusCode: 200 on success, 404 if no files are found, or 500 if an error occurs.
          - Content: The minified JSON string.
          - Reason: A descriptive message indicating success or detailing any errors encountered.

    .PARAMETER InputDirectory
        The folder path where CSV or JSON files are queued for processing.

    .PARAMETER ArchiveDirectory
        The folder path where processed files are archived.

    .PARAMETER Session
        A unique identifier (e.g., a session ID) appended to the archived file name to ensure uniqueness and traceability.

    .EXAMPLE
        $result = Get-NextFile -InputDirectory "C:\MyBot\input" -ArchiveDirectory "C:\MyBot\archive" -Session "12345"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$InputDirectory,
        [Parameter(Mandatory = $true)][string]$ArchiveDirectory,
        [Parameter(Mandatory = $true)][string]$Session
    )

    Write-Verbose "Initialize variables for the result object and the reference to the latest file found"
    $resultObject = $null
    $latestFile   = $null

    try {
        Write-Verbose "Retrieve all files in InputDirectory with .csv or .json extensions"
        $files = Get-ChildItem -Path $InputDirectory -File | Where-Object { $_.Extension -in ".csv", ".json" }
   
        # If no file is found, return a result object with a 404 status.
        if (-not $files) {
            Write-Verbose "No file is found, return a result object with a 404 status"
            $resultObject = [PSCustomObject]@{
                StatusCode = 404
                Content    = $null
                Reason     = "No CSV or JSON files found in input folder: $InputDirectory"
            }
            return $resultObject
        }

        Write-Verbose "Sort files by LastWriteTime in descending order and select the most recent one"
        $latestFile = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        Write-Verbose "Process the file based on its extension"
        if ($latestFile.Extension -eq ".csv") {
            Write-Verbose "Import CSV data and convert it to a minified JSON string"
            $csvData     = Import-Csv -Path $latestFile.FullName -Encoding UTF8
            $jsonContent = $csvData | ConvertTo-Json -Depth 3 -Compress
        }
        elseif ($latestFile.Extension -eq ".json") {
            Write-Verbose "Read the entire JSON content from the file"
            $rawJson = [System.IO.File]::ReadAllText($latestFile.FullName, [System.Text.Encoding]::UTF8)

            Write-Verbose "Validate the JSON by converting it into an object"
            try {
                $jsonObject = $rawJson | ConvertFrom-Json
            }
            catch {
                throw "File $($latestFile.FullName) is not a valid JSON file."
            }

            Write-Verbose "Re-serialize the JSON object into a minified JSON string"
            $jsonContent = $jsonObject | ConvertTo-Json -Depth 10 -Compress
        }
        else {
            throw "Unsupported file type: $($latestFile.Extension)"
        }

        Write-Verbose "Ensure the JSON content is formatted as an array. If not, wrap it in an array"
        if ($jsonContent[0] -ne '[' -or $jsonContent[-1] -ne ']') {
            $jsonContent = "[$jsonContent]"
        }

        Write-Verbose "Build the success result object"
        $resultObject = [PSCustomObject]@{
            StatusCode = 200
            Content    = $jsonContent
            Reason     = "File processed successfully: $($latestFile.Name)"
        }
    }
    catch {
        Write-Verbose "Return a result object with a 500 status and include the error message"
        $resultObject = [PSCustomObject]@{
            StatusCode = 500
            Content    = $null
            Reason     = $_.Exception.GetBaseException().Message
        }
    }
    finally {
        Write-Verbose "Attempt to archive the processed file"
        if ($latestFile -and (Test-Path -Path $latestFile.FullName)) {
            try {
                # TODO: Rethink session in the file name
                Write-Verbose "Construct the archive file name by appending the Session ID to ensure uniqueness"
                $baseName        = [System.IO.Path]::GetFileNameWithoutExtension($latestFile.Name)
                $extension       = [System.IO.Path]::GetExtension($latestFile.Name)
                $archiveFileName = "$baseName-$Session$extension"
                $archiveFilePath = Join-Path $ArchiveDirectory $latestFile.Name

                Write-Verbose "Move the file to the ArchiveDirectory"
                Move-Item -Path $latestFile.FullName -Destination $archiveFilePath -Force
            }
            catch {
                Write-Verbose "Archiving failed, appending the error to the result object's Reason"
                $archiveError = "Failed to archive file: $($_.Exception.GetBaseException().Message)"
                if ($null -ne $resultObject) {
                    $resultObject.Reason += " | " + $archiveError
                }
                else {
                    $resultObject = [PSCustomObject]@{
                        StatusCode = 500
                        Content    = $null
                        Reason     = $archiveError
                    }
                }
            }
        }
    }
    return $resultObject
}

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
        Write-Warning "The environment file was not found at path: $EnvironmentFilePath"
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
            Write-Verbose "Skipping environment variable '$key' as it is in the skip list."
            return
        }
        
        Write-Verbose "Set the environment variable for the current process using Set-Item"
        Set-Item -Path "Env:$($key)" -Value $value
        Write-Host "Set environment variable '$key' with value '$value'"
    }
}

function Wait-Interval {
    <#
    .SYNOPSIS
        Pauses script execution for a specified interval after displaying the next scheduled invocation time.

    .DESCRIPTION
        This function calculates the next automation invocation time by adding the provided interval (in seconds)
        to the current time. It then formats and displays this time in ISO 8601 format along with a custom message,
        and finally pauses execution for the full interval.

    .PARAMETER Message
        A custom message to display along with the next scheduled invocation time.

    .PARAMETER IntervalTime
        The time interval (in seconds) to wait before the next automation invocation.

    .EXAMPLE
        Wait-Interval -Message "Next automation run scheduled at:" -IntervalTime 120
    #>
    [CmdletBinding()]
    param(
        [int]   $IntervalTime,
        [string]$Message
    )

    Write-Verbose "Calculate the next scheduled time by adding the specified interval to the current date and time"
    $nextAutomationTime = (Get-Date).AddSeconds($IntervalTime)

    Write-Verbose "Format the calculated time in ISO 8601 format"
    $isoNextAutomation = $nextAutomationTime.ToString("o")

    Write-Verbose "$Message$isoNextAutomation"

    Write-Verbose "Pause execution for the specified interval"
    Start-Sleep -Seconds $IntervalTime
}

# If the Docker switch is specified, launch a Docker container with the given parameters and exit.
if ($Docker) {
    try {
        Write-Host "Docker mode enabled. Attempting to launch Docker container..."
        docker run -d -v "$($BotVolume):/bots" `
            -e BOT_NAME="$($BotName)" `
            -e DRIVER_BINARIES="$($DriverBinaries)" `
            -e HUB_URI="$($HubUri)" `
            -e INTERVAL_TIME="$($IntervalTime)" `
            -e TOKEN="$($Token)" `
            --name "$($BotName)-$([guid]::NewGuid())" g4-file-listener-bot:latest

        Write-Verbose "Docker container '$($BotName)' started successfully."
        Exit 0
    }
    catch {
        # Output error message and exit with a non-zero code if the Docker container fails to start.
        Write-Error "Failed to start Docker container '$($BotName)': $($_.Exception.GetBaseException())"
        Exit 1
    }
}

try {
    Write-Verbose "Setting Environment Parameters"
    Import-EnvironmentVariablesFile -Verbose
}
catch {
    Write-Error "Failed to set environment parameters: $($_.Exception.GetBaseException().Message)"
}

# Construct the request URI by ensuring no trailing slash exists and appending the API endpoint.
$requestUri = "$($HubUri.TrimEnd('/'))/api/v4/g4/automation/base64/invoke"

# Define directory paths for various bot operations.
$archiveDirectory       = [System.IO.Path]::Combine($BotVolume, $BotName, "archive")
$inputDirectory         = [System.IO.Path]::Combine($BotVolume, $BotName, "input")
$outputDirectory        = [System.IO.Path]::Combine($BotVolume, $BotName, "output")
$botDirectory           = Join-Path $BotVolume $BotName
$botAutomationDirectory = Join-Path $botDirectory "bot"
$botFilePath            = Join-Path $botAutomationDirectory "automation.json"

Write-Host
Write-Host "Listening for incoming files for bot '$BotName' in directory '$inputDirectory'.$([System.Environment]::NewLine)Press [Ctrl] + [C] to stop the script."

# Main loop: Continuously process available files and invoke the remote automation endpoint.
while ($true) {
   # Construct file paths for output and error logs.
   $session        = (Get-Date).ToString("yyyyMMddHHmmssfff")
   $outputFilePath = [System.IO.Path]::Combine($outputDirectory, "$($BotName)-$($session).json")
   $errorsPath     = [System.IO.Path]::Combine($BotVolume, $BotName, "errors", "$($BotName)-$($session).json")

    try {
        # Check if the 'automation.json' configuration file exists in the bot automation directory.
        if (-Not (Test-Path $botFilePath)) {
            Write-Verbose "Configuration file 'automation.json' not found in '$botAutomationDirectory'. Waiting for the next interval..."
            Wait-Interval -Message "Next check scheduled at:" -IntervalTime $IntervalTime
            continue
        }

        Write-Verbose "Searching for the next file to process in '$inputDirectory'..."
        $nextFile = Get-NextFile -InputDirectory $inputDirectory -ArchiveDirectory $archiveDirectory -Session $session

        # If no valid file is found, log the reason and wait for the next check.
        if ($nextFile.StatusCode -gt 200) {
            Write-Verbose "Skipping file processing: $($nextFile.Reason). Waiting for the next interval..."
            Wait-Interval -Message "Next check scheduled at:" -IntervalTime $IntervalTime
            continue
        }

        # Happy flow: a file was found. Display the indicator using Write-Host.
        Write-Host "Processing session: $session"

        # Read the entire content of 'automation.json' as raw text.
        $botFileContent = [System.IO.File]::ReadAllText($botFilePath, [System.Text.Encoding]::UTF8)

        # Convert the JSON text to an object to update the 'driverBinaries' property.
        $botFileJson = ConvertFrom-Json $botFileContent

        # Create or update the 'dataSource' property with the file content.
        $dataSourceValue = @{
            type   = "JSON"
            source = $nextFile.Content
        }
        if (-not $botFileJson.PSObject.Properties['dataSource']) {
            Add-Member -InputObject $botFileJson -MemberType NoteProperty -Name "dataSource" -Value $dataSourceValue
        }
        else {
            $botFileJson.dataSource = $dataSourceValue
        }

        # Update other configuration properties.
        $botFileJson.driverParameters.driverBinaries = $DriverBinaries
        $botFileJson.authentication.token = $Token

        # Serialize the updated JSON and convert it to a Base64-encoded string.
        $botFileContent = ConvertTo-Json $botFileJson -Depth 50 -Compress
        $botBytes   = [System.Text.Encoding]::UTF8.GetBytes($botFileContent)
        $botContent = [System.Convert]::ToBase64String($botBytes)

        Write-Verbose "Sending Base64-encoded 'automation.json' to remote endpoint at $requestUri..."
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

    # Verbose message for the next check.
    Write-Verbose "Next bot invocation scheduled. Waiting for $IntervalTime..."
    Wait-Interval -IntervalTime $IntervalTime -Message "Next check scheduled at: "
}
