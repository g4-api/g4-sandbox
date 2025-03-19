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
    [string]$BotVolume,
    [string]$BotName,
    [string]$CronSchedules,
    [string]$DriverBinaries,
    [string]$HubUri,
    [string]$Token,
    [switch]$Docker
)

# If the Docker switch is provided, attempt to start the Docker container and exit.
if ($Docker) {
    try {
        # Attempt to start the Docker container using the provided parameters.
        docker run -d -v "$($BotVolume):/bots" -e BOT_NAME="$($BotName)" -e CRON_SCHEDULES="$($CronSchedules)" -e DRIVER_BINARIES="$($DriverBinaries)" -e HUB_URI="$($HubUri)" -e TOKEN="$($Token)" --name "$($BotName)-$([guid]::NewGuid())" g4-cron-bot:latest
        
        Write-Host "Docker container '$($BotName)' started successfully."
        Exit 0
    }
    catch {
        # If an error occurs while starting the Docker container, output the error and exit with a non-zero code.
        Write-Error "Failed to start Docker container '$($BotName)': $_"
        Exit 1
    }
}

# Build the final request URL by removing any trailing slash from $HubUri and appending the endpoint path.
$requestUri = "$($HubUri.TrimEnd('/'))/api/v4/g4/automation/base64/invoke"

# Construct the full path to the output directory where responses will be saved.
$outputDirectory = [System.IO.Path]::Combine($BotVolume, $BotName, "output")

Write-Host
Write-Host "Starting main process. Press [Ctrl] + [C] to stop the script."

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
        Write-Host "File 'automation.json' not found in '$botAutomationDirectory'. Waiting for next interval."
        exit 0
    }

    # Generate a unique session timestamp for file naming and session identification.
    $session = (Get-Date).ToString("yyyyMMddHHmmssfff")
    
    # Create the output file path using the session timestamp.
    $outputFilePath = [System.IO.Path]::Combine($outputDirectory, "$($BotName)-$($session).json")
    
    # Create the error file path (inside an 'errors' folder) using the session timestamp.
    $errorsPath = [System.IO.Path]::Combine($BotVolume, $BotName, "errors", "$($BotName)-$($session).json")
    
    # Read the entire content of 'automation.json' as raw text.
    $botFileContent = Get-Content $botFilePath -Raw

    # Convert the JSON text to an object to update the 'driverBinaries' property.
    $botFileJson = ConvertFrom-Json $botFileContent

    # Update the 'driverBinaries' property within the driverParameters object.
    $botFileJson.driverParameters.driverBinaries = $DriverBinaries

    # Update the 'token' property within the authentication object.
    $botFileJson.authentication.token = $Token

    # Convert the modified JSON object back to a JSON string with sufficient depth.
    $botFileContent = ConvertTo-Json $botFileJson -Depth 50

    # Convert the updated JSON text to a byte array and encode it in Base64.
    $botBytes = [System.Text.Encoding]::UTF8.GetBytes($botFileContent)
    $botContent = [System.Convert]::ToBase64String($botBytes)

    # Send the Base64-encoded string via a POST request to the remote endpoint.
    # The timestamp in ISO 8601 format is prepended to the message.
    Write-Host "$(Get-Date -Format o): Sending Base64-encoded 'automation.json' to remote endpoint..."
    $response = Invoke-RestMethod -Uri $requestUri -Method Post -Body $botContent -ContentType "text/plain"
}
catch {
    # If an error occurs during processing, output a message and log the error details to the errors file.
    Write-Host "An error occurred during processing. Check the error file at '$errorsPath' for details."
    "Error: $_" | Out-File -FilePath $errorsPath -Force -ErrorAction Continue
}
finally {
    # Save the response from the remote endpoint (if any) to the output file for record-keeping.
    Write-Host "$(Get-Date -Format o): Saving response to $outputFilePath."
    $response | ConvertTo-Json -Depth 30 -ErrorAction Continue | Out-File -FilePath $outputFilePath -Force -ErrorAction Continue
}
