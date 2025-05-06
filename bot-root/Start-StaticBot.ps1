<#
WORK ITEMS:
    [ ] - Refactor main loop to be non-blocking process and interval every 1000ms. Will allow early exit on long bot intervals.
#>
param (
    [CmdletBinding()]
    [Parameter(Mandatory = $false)] [string] $BotId="$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())",
    [Parameter(Mandatory = $true)]  [string] $BotName,
    [Parameter(Mandatory = $true)]  [string] $BotVolume,
    [Parameter(Mandatory = $false)] [string] $CallbackIngress,
    [Parameter(Mandatory = $false)] [string] $CallbackUri,
    [Parameter(Mandatory = $true)]  [string] $DriverBinaries,
    [Parameter(Mandatory = $true)]  [string] $HubUri,
    [Parameter(Mandatory = $true)]  [string] $IntervalTime,
    [Parameter(Mandatory = $false)] [string] $Token,
    [Parameter(Mandatory = $false)] [switch] $Docker
)

# Change to the script's own directory so any relative paths resolve correctly
Set-Location -Path $PSScriptRoot

# Import the setup and common modules for bot initialization and utilities
Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'modules', 'BotSetup.psm1'))  -Force
Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'modules', 'BotLogger.psm1')) -Force

# Return to the script directory (in case module import changed location)
Set-Location -Path $PSScriptRoot

# Build the bot's configuration object (endpoints, metadata, timeouts)
$botConfiguration = New-BotConfiguration `
    -BotId               $BotId `
    -BotName             $BotName `
    -BotType             'static-bot' `
    -BotVolume           $BotVolume `
    -CallbackIngress     $CallbackIngress `
    -CallbackUri         $CallbackUri `
    -DriverBinaries      $DriverBinaries `
    -EntryPointPort      $EntryPointPort `
    -EnvironmentFilePath (Join-Path $PSScriptRoot ".env") `
    -HubUri              $HubUri `
    -Token               $Token

# Only proceed if Docker support is enabled
if ($Docker) {
    try {
        Write-Log -Level Verbose -UseColor -Message "Docker switch is enabled. Preparing to launch Docker container for bot '$($botConfiguration.Metadata.BotName)'."
        Write-Log -Level Verbose -UseColor -Message "Building the Docker command from the specified parameters."

        # Initialize an array of docker run arguments
        $cmdLines = @(
            "run -d -v `"$($botConfiguration.Directories.BotVolume):/bots`""
            " -e BOT_ID=`"$($botConfiguration.Metadata.BotId)`""
            " -e BOT_NAME=`"$($botConfiguration.Metadata.BotName)`""
            " -e CALLBACK_INGRESS=`"$($botConfiguration.Endpoints.BotCallbackIngress)`""
            " -e CALLBACK_URI=`"$($botConfiguration.Endpoints.BotCallbackUri)`""
            " -e DRIVER_BINARIES=`"$($botConfiguration.Endpoints.DriverBinaries)`""
            " -e HUB_URI=`"$($botConfiguration.Endpoints.HubUri)`""
            " -e INTERVAL_TIME=`"$($IntervalTime)`""
            " -e TOKEN=`"$($botConfiguration.Metadata.Token)`""
        )

        # Optionally add SAVE_OUTPUT flag when requested
        $cmdLines += if ($SaveOutput) { " -e SAVE_OUTPUT=`"true`"" }
        
        # Publish port and assign unique container name
        $cmdLines += " -p $($botConfiguration.Endpoints.CallbackPort):$($botConfiguration.Endpoints.CallbackPort) --name `"$($botConfiguration.Metadata.BotName)-$([guid]::NewGuid())`" g4-static-bot:latest"

        # Combine the array of arguments into one continuous string
        Write-Log -Level Verbose -UseColor -Message "Joining command parts into a single Docker command string."
        $dockerCmd = $cmdLines -join [string]::Empty

        # Wait up to 60 seconds for the container to start
        Write-Log -Level Verbose -UseColor -Message "Invoking Docker with the following command:$([System.Environment]::NewLine)docker $($dockerCmd)"
        $process = Start-Process -FilePath "docker" -ArgumentList $dockerCmd -PassThru
        $process.WaitForExit(60000)

        # Exit successfully if no errors
        Exit 0
    }
    catch {
        # Exit with error code
        # Report error details on failure
        Write-Log -Level Critical -UseColor -Message "Failed to start Docker container '$($BotName)': $($_.Exception.GetBaseException())"
        Exit 1
    }
}

# Build the bot configuration object with endpoints, metadata, and timeouts
$bot = Initialize-BotByConfiguration -BotConfiguration $botConfiguration

# Display startup message and instructions
Write-Host
Write-Host "Starting main bot loop.`nPress [Ctrl] + [C] to stop bot.`n"

# Loop until the callback listener runspace completes
while (-not $bot.CallbackJob.AsyncResult.IsCompleted -and $bot.CallbackJob.Runner.InvocationStateInfo.State -eq 'Running') {
    try {
        # Check if the automation file exists; if not, wait and retry
        if (-Not (Test-BotFile -BotFilePath $bot.Configuration.Directories.BotAutomationFile)) {
            Wait-Interval -Message "Next check scheduled at:" -IntervalTime $IntervalTime
            continue
        }

        # Generate timestamp for this session to name output and error files
        $session = (Get-Date).ToString("yyyyMMddHHmmssfff")

        # Determine paths for output and error JSON files
        $outputFilePath = [System.IO.Path]::Combine($bot.Configuration.Directories.BotOutputDirectory, "$($BotName)-$($session).json")
        $errorFilePath  = Join-Path $bot.Configuration.Directories.BotErrorsDirectory "$($BotName)-$($session).json"

        # Read and parse the automation JSON file
        $botFileContent = [System.IO.File]::ReadAllText($bot.Configuration.Directories.BotAutomationFile, [System.Text.Encoding]::UTF8)
        $botFileJson    = ConvertFrom-Json $botFileContent

        # Inject dynamic values: driver binaries URL and authentication token
        $botFileJson.driverParameters.driverBinaries = $bot.Configuration.Endpoints.DriverBinaries
        $botFileJson.authentication.token            = $bot.Configuration.Metadata.Token

        # Serialize back to JSON and encode as Base64
        $botFileContent = ConvertTo-Json $botFileJson -Depth 50
        $botBytes       = [System.Text.Encoding]::UTF8.GetBytes($botFileContent)
        $botContent     = [System.Convert]::ToBase64String($botBytes)

        # Notify the hub that the bot is now Working, suppressing any output
        Update-BotStatus `
            -BotId  $bot.Configuration.Metadata.BotId `
            -HubUri $bot.Configuration.Endpoints.HubUri `
            -Status "Working" | Out-Null

        # Send the automation request and capture the response
        $response = Send-BotAutomationRequest `
            -HubUri         $bot.Configuration.Endpoints.HubUri `
            -Base64Request  $botContent

        # If the call failed (HTTP >= 400), save the error details
        if ($response.StatusCode -ge 400 -and $botConfiguration.Settings.SaveErrors) {
            Set-Content -Value $response.JsonValue -Path $errorFilePath
        }

        # On success (HTTP 200), optionally save the output JSON
        if ($response.StatusCode -eq 200 -and $botConfiguration.Settings.SaveResponse) {
            Set-Content -Value $response.JsonValue -Path $outputFilePath
        }

        # Notify the hub that the bot is now Ready, suppressing any output
        Update-BotStatus `
            -BotId  $bot.Configuration.Metadata.BotId `
            -HubUri $bot.Configuration.Endpoints.HubUri `
            -Status "Ready" | Out-Null

        # Wait for the configured interval before the next iteration
        Wait-Interval `
            -IntervalTime $IntervalTime `
            -Message "Next bot invocation scheduled at"
    }
    catch {
        # Catch any unexpected errors, log a warning, and wait before retry
        Write-Log -Level Error -Message "(Main) $($_)" -UseColor
        Wait-Interval `
            -IntervalTime $IntervalTime `
            -Message "Next bot invocation scheduled at"
    }
}
