<#
.SYNOPSIS
    Periodically processes an 'automation.json' file by encoding its content in Base64,
    sending it to a remote endpoint, and saving both the responses and any errors.

.DESCRIPTION
    This script continuously performs the following steps:
    1. Locates a bot subfolder named after the provided $BotName within the specified $BotVolume.
    2. Searches for an 'automation.json' file in the bot's "bot" subdirectory.
    3. Reads the file, parses its JSON content, updates the 'driverBinaries' property and the 'token'
       property within the 'authentication' object. The JSON is then re-serialized to text and encoded in Base64.
    4. Sends the Base64-encoded string via a POST request to a remote endpoint constructed from $HubUri,
       with the '/api/v4/g4/automation/base64/invoke' path appended.
    5. Saves the JSON response in an 'output' directory with a timestamped filename.
    6. Logs any errors in an 'errors' directory with a timestamped filename.
    7. Calculates the next invocation time by adding $IntervalTime seconds to the current time, displays
       it in ISO 8601 format, and then pauses for the full interval.
    8. Repeats the process indefinitely.

.NOTES
    - Designed for demonstration and automation testing purposes.
    - Requires PowerShell 5.1+ (or later) for best compatibility.
    - When the -Docker switch is specified, the script starts a Docker container with the provided
      parameters and then exits.

.PARAMETER BotVolume
    The path to the main directory where the bot subfolder resides.

.PARAMETER BotName
    The name of the bot's subfolder. This folder should contain a "bot" directory that includes an 'automation.json' file.

.PARAMETER DriverBinaries
    The URL for the driver binaries to be injected into the automation JSON.

.PARAMETER HubUri
    The base URI of the remote service (e.g., http://host.docker.internal:9944).

.PARAMETER IntervalTime
    The time interval (in seconds) to wait between successive invocations (e.g., 120 for 2 minutes).

.PARAMETER Token
    The authentication token required for the bot's operation. This token is inserted into the automation JSON.

.PARAMETER Docker
    Switch to run the script inside a Docker container. When specified, the script will launch a Docker container
    using the given parameters and then exit.

.EXAMPLE
    .\LoopScript.ps1 -BotVolume "E:\Garbage\bot-volume" -BotName "demo-bot" -DriverBinaries "http://host.k8s.internal" -HubUri "http://host.docker.internal:9944" -IntervalTime 120 -Token "your_token"
#>
param (
    [string]$BotVolume,
    [string]$BotName,
    [string]$DriverBinaries,
    [string]$HubUri,
    [string]$IntervalTime,
    [string]$Token,
    [switch]$Docker
)

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
    Write-Host "$Message $isoNextAutomation"

    # Pause execution for the specified interval.
    Start-Sleep -Seconds $IntervalTime
}

# If the Docker switch is specified, start a Docker container with the given parameters and exit.
if ($Docker) {
    try {
        # Launch the Docker container:
        # - Mount the BotVolume to /bots in the container.
        # - Pass the required environment variables to configure the bot.
        docker run -d -v "$($BotVolume):/bots" -e BOT_NAME="$($BotName)" -e DRIVER_BINARIES="$($DriverBinaries)" -e HUB_URI="$($HubUri)" -e INTERVAL_TIME="$($IntervalTime)" -e TOKEN="$($Token)" --name "$($BotName)-$([guid]::NewGuid())" g4-static-bot:latest
        
        Write-Host "Docker container '$($BotName)' started successfully."
        Exit 0
    }
    catch {
        # If an error occurs while starting Docker, output the error message and exit with a non-zero code.
        Write-Error "Failed to start Docker container '$($BotName)': $_"
        Exit 1
    }
}

# Construct the full request URL by trimming any trailing slash from $HubUri and appending the endpoint path.
$requestUri = "$($HubUri.TrimEnd('/'))/api/v4/g4/automation/base64/invoke"

# Define the path to the output directory where responses will be saved.
$outputDirectory = [System.IO.Path]::Combine($BotVolume, $BotName, "output")

Write-Host
Write-Host "Starting main loop. Press [Ctrl] + [C] to stop the script."

# Build the complete path to the bot's automation file:
# 1. Combine $BotVolume and $BotName to form the bot directory.
# 2. Append "bot" to locate the bot automation subdirectory.
# 3. Append "automation.json" to form the full file path.
$botDirectory           = Join-Path $BotVolume $BotName
$botAutomationDirectory = Join-Path $botDirectory "bot"
$botFilePath            = Join-Path $botAutomationDirectory "automation.json"

while ($true) {
    try {
        # Verify if the 'automation.json' file exists in the bot automation directory.
        if (-Not (Test-Path $botFilePath)) {
            Write-Host "File 'automation.json' not found in '$botAutomationDirectory'. Waiting for next interval."
            Wait-Interval -Message "Next check scheduled at:" -IntervalTime $IntervalTime
            
            # Skip the current iteration and continue looping.
            continue
        }

        # Generate a unique timestamp to identify this session (used for naming files).
        $session = (Get-Date).ToString("yyyyMMddHHmmssfff")
        
        # Construct the output file path using the session timestamp.
        $outputFilePath = [System.IO.Path]::Combine($outputDirectory, "$($BotName)-$($session).json")
        
        # Construct the error log file path within the 'errors' directory using the session timestamp.
        $errorsPath = [System.IO.Path]::Combine($BotVolume, $BotName, "errors", "$($BotName)-$($session).json")
        
        # Read the entire content of 'automation.json' as raw text.
        $botFileContent = Get-Content $botFilePath -Raw

        # Parse the JSON text into an object for modification.
        $botFileJson = ConvertFrom-Json $botFileContent

        # Update the 'driverBinaries' property within the 'driverParameters' object.
        $botFileJson.driverParameters.driverBinaries = $DriverBinaries

        # Update the 'token' property within the 'authentication' object.
        $botFileJson.authentication.token = $Token

        # Re-serialize the updated JSON object back to text, ensuring sufficient depth.
        $botFileContent = ConvertTo-Json $botFileJson -Depth 50

        # Convert the JSON text to a byte array and encode it in Base64.
        $botBytes = [System.Text.Encoding]::UTF8.GetBytes($botFileContent)
        $botContent = [System.Convert]::ToBase64String($botBytes)

        # Send the Base64-encoded JSON to the remote endpoint using a POST request.
        Write-Host
        Write-Host "Sending Base64-encoded 'automation.json' to remote endpoint..."
        $response = Invoke-RestMethod -Uri $requestUri -Method Post -Body $botContent -ContentType "text/plain"
    }
    catch {
        # If an error occurs, display a message and log the error details to the designated errors file.
        Write-Host "An error occurred. Check $errorsPath for details."
        "Error: $_" | Out-File -FilePath $errorsPath -Force -ErrorAction Continue
    }
    finally {
        # Save the response from the remote endpoint (if any) to the output file for record-keeping.
        Write-Host "Saving response to $outputFilePath."
        $response | ConvertTo-Json -Depth 30 -ErrorAction Continue | Out-File -FilePath $outputFilePath -Force -ErrorAction Continue
    }

    # Wait for the specified interval before starting the next iteration.
    Write-Host
    Wait-Interval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
}
