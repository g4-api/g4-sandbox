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
    [Parameter(Mandatory = $true)][string]$BotVolume,
    [Parameter(Mandatory = $true)][string]$BotName,
    [Parameter(Mandatory = $true)][string]$DriverBinaries,
    [Parameter(Mandatory = $true)][string]$HubUri,
    [Parameter(Mandatory = $true)][string]$IntervalTime,
    [Parameter(Mandatory = $true)][string]$Token,
    [switch]$Docker
)

function Get-NextFile {
    <#
    .SYNOPSIS
        Processes the latest file (CSV or JSON) from an input folder, converts CSV files to minified JSON if needed,
        archives the file, and returns the minified JSON content.

    .DESCRIPTION
        This function searches the specified InputDirectory for files with .csv or .json extensions and selects
        the most recent one based on LastWriteTime. If the file is a CSV, it imports the data and converts it
        to a JSON object; if it is a JSON file, it validates and then normalizes the JSON. In both cases, the
        JSON output is minified using the -Compress parameter. Regardless of success or failure in processing,
        the file is moved (archived) in the finally block. Any error encountered during the move is appended to
        the Reason field. The function returns a custom object with:
          - StatusCode: 200 for success, 404 if no file is found, or 500 if an error occurs.
          - Content: The minified JSON content (either converted from CSV or validated JSON).
          - Reason: A description of the outcome and any additional error messages.

    .PARAMETER InputDirectory
        The folder path that serves as the queue where files (CSV or JSON) are dropped.

    .PARAMETER ArchiveDirectory
        The folder path where processed files should be archived.

    .EXAMPLE
        PS C:\> $result = Get-NextFile -InputDirectory "C:\MyBot\input" -ArchiveDirectory "C:\MyBot\archive"
        PS C:\> if ($result.StatusCode -eq 200) {
                    Write-Host "Minified JSON content:`n$result.Content"
                } else {
                    Write-Host "Error: $($result.Reason)"
                }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDirectory,

        [Parameter(Mandatory = $true)]
        [string]$ArchiveDirectory
    )

    # Initialize variables for the result object and the latest file reference
    $resultObject = $null
    $latestFile   = $null

    try {
        # Retrieve all files with .csv or .json extensions from the InputDirectory
        $files = Get-ChildItem -Path $InputDirectory -File | Where-Object { $_.Extension -in ".csv", ".json" }

        # If no file is found, return a 404 result immediately
        if (-not $files) {
            $resultObject = [PSCustomObject]@{
                StatusCode = 404
                Content    = $null
                Reason     = "No CSV or JSON files found in input folder: $InputDirectory"
            }
            return $resultObject
        }

        # Sort files by LastWriteTime (newest first) and select the latest file
        $latestFile = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        # Process the file based on its extension
        # Import CSV data and convert it to a minified JSON string
        if ($latestFile.Extension -eq ".csv") {
            $csvData = Import-Csv -Path $latestFile.FullName -Encoding UTF8
            $jsonContent = $csvData | ConvertTo-Json -Depth 3 -Compress
        }
        elseif ($latestFile.Extension -eq ".json") {
            # Read the raw JSON content from the file
            $rawJson = [System.IO.File]::ReadAllText($latestFile.FullName, [System.Text.Encoding]::UTF8)

            # Validate the JSON by attempting to convert it to an object
            try {
                $jsonObject = $rawJson | ConvertFrom-Json
            }
            catch {
                throw "File $($latestFile.FullName) is not a valid JSON file."
            }

            # Convert the JSON object back to a minified JSON string (ensuring it's an array)
            $jsonContent = $jsonObject | ConvertTo-Json -Depth 10 -Compress
        }
        else {
            throw "Unsupported file type: $($latestFile.Extension)"
        }

        # Check if the resulting JSON starts with '[' and ends with ']'
        if ($jsonContent[0] -ne '[' -or $jsonContent[-1] -ne ']') {
            $jsonContent = "[$jsonContent]"
        }

        # Set the result as a successful operation
        $resultObject = [PSCustomObject]@{
            StatusCode = 200
            Content    = $jsonContent
            Reason     = "File processed successfully: $($latestFile.Name)"
        }
    }
    catch {
        # On error during processing, capture the error message and set a 500 status
        $resultObject = [PSCustomObject]@{
            StatusCode = 500
            Content    = $null
            Reason     = $_.Exception.Message
        }
    }
    finally {
        # In the finally block, attempt to move the processed file to the ArchiveDirectory
        if ($latestFile -and (Test-Path -Path $latestFile.FullName)) {
            try {
                $archiveFilePath = Join-Path $ArchiveDirectory $latestFile.Name
                Move-Item -Path $latestFile.FullName -Destination $archiveFilePath -Force
            }
            catch {
                # Append any error encountered during the move operation to the Reason field
                $archiveError = "Failed to archive file: $($_.Exception.Message)"
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
        Imports environment variables from an environment file into the current session.

    .DESCRIPTION
        This function reads an environment file (with each line in the format KEY=value),
        splits each line on the first "=" occurrence (allowing values to contain additional "=" characters),
        and assigns the variables to the current session's environment.
        A list of environment variable names to skip can be provided, and those keys will not be imported.

    .PARAMETER EnvironmentFilePath
        The full path to the environment file. Defaults to ".env" if not specified.

    .PARAMETER SkipNames
        An array of environment variable names that should not be imported from the file.

    .EXAMPLE
        Import-EnvironmentVariablesFile -EnvironmentFilePath ".\config\environment.env" -SkipNames "PATH","JAVA_HOME"
        Imports environment variables from the specified file, skipping the variables named PATH and JAVA_HOME.

    .EXAMPLE
        Import-EnvironmentVariablesFile
        Imports environment variables from a file named .env in the current directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$EnvironmentFilePath = (Join-Path $PSScriptRoot ".env"),
        
        [Parameter(Mandatory = $false)]
        [string[]]$SkipNames = @()
    )

    # Check if the environment file exists; if not, display a message and exit.
    if (-Not (Test-Path $EnvironmentFilePath)) {
        Write-Warning "The environment file was not found at path: $EnvironmentFilePath"
        return
    }

    # Read the environment file line by line.
    Get-Content $EnvironmentFilePath -Force -Encoding UTF8 | ForEach-Object {
        # Skip lines that are comments (starting with '#') or empty after trimming whitespace.
        if ($_.Trim().StartsWith("#") -or [string]::IsNullOrWhiteSpace($_)) {
            return
        }

        # Split the line into two parts at the first '=' occurrence.
        $parts = $_.Split('=', 2)
        
        # If the line does not contain exactly two parts, skip it.
        if ($parts.Length -ne 2) {
            return
        }
        
        # Trim any leading or trailing whitespace from the key and value.
        $key   = $parts[0].Trim()
        $value = $parts[1].Trim()

        # Skip this key if it is in the skip list.
        if ($SkipNames -contains $key) {
            Write-Verbose "Skipping environment variable '$key' as it is in the skip list."
            return
        }
        
        # Set the environment variable for the current process using Set-Item.
        Set-Item -Path "Env:$key" -Value $value

        # Write a verbose message showing the key-value pair that was set.
        Write-Verbose "Set environment variable '$key' with value '$value'"
    }
}

function Wait-Interval {
    [CmdletBinding()]
    param(
        [int]   $IntervalTime,
        [string]$Message
    )

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

    # Calculate the next scheduled time by adding the specified interval to the current date and time.
    $nextAutomationTime = (Get-Date).AddSeconds($IntervalTime)

    # Format the calculated time in ISO 8601 format.
    $isoNextAutomation = $nextAutomationTime.ToString("o")

    # Display the custom message along with the formatted next invocation time.
    Write-Verbose "$Message$isoNextAutomation"

    # Pause execution for the specified interval.
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
        Write-Error "Failed to start Docker container '$($BotName)': $_"
        Exit 1
    }
}

try {
    Write-Verbose "Setting Environment Parameters"
    Import-EnvironmentVariablesFile -Verbose
}
catch {
    Write-Error "Failed to set environment parameters: $_"
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
    try {
        # Check if the 'automation.json' configuration file exists in the bot automation directory.
        if (-Not (Test-Path $botFilePath)) {
            Write-Verbose "Configuration file 'automation.json' not found in '$botAutomationDirectory'. Waiting for the next interval..."
            Wait-Interval -Message "Next check scheduled at:" -IntervalTime $IntervalTime
            continue
        }

        Write-Verbose "Searching for the next file to process in '$inputDirectory'..."
        $nextFile = Get-NextFile -InputDirectory $inputDirectory -ArchiveDirectory $archiveDirectory

        # If no valid file is found, log the reason and wait for the next check.
        if ($nextFile.StatusCode -gt 200) {
            Write-Verbose "Skipping file processing: $($nextFile.Reason). Waiting for the next interval..."
            Wait-Interval -Message "Next check scheduled at:" -IntervalTime $IntervalTime
            continue
        }

        # Construct file paths for output and error logs.
        $session        = (Get-Date).ToString("yyyyMMddHHmmssfff")
        $outputFilePath = [System.IO.Path]::Combine($outputDirectory, "$($BotName)-$($session).json")
        $errorsPath     = [System.IO.Path]::Combine($BotVolume, $BotName, "errors", "$($BotName)-$($session).json")

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
        Write-Error "An error occurred during processing. Check error log at: $errorsPath. Error details: $_"
        @{ error = "InternalServerError"; message = $_.Exception.Message } | ConvertTo-Json -Depth 30 -Compress -ErrorAction Continue | Out-File -FilePath $errorsPath -Force -ErrorAction Continue
    }
    finally {      
        try {
            if(Test-Path $outputFilePath) {
                $response | ConvertTo-Json -Depth 30 -Compress -ErrorAction Continue | Out-File -FilePath $outputFilePath -Force -ErrorAction Continue
                Write-Verbose "Response successfully saved to: $outputFilePath"   
            }
        }
        catch {
            Write-Error "Failed to save response to: $outputFilePath. Error details: $_"
        }
    }

    # Verbose message for the next check.
    Write-Verbose "Next bot invocation scheduled. Waiting for $IntervalTime..."
    Wait-Interval -IntervalTime $IntervalTime -Message "Next check scheduled at: "
}
