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

.PARAMETER RetentionThreshold
    (Optional) The number of recent responses to retain. Older files beyond this threshold may be deleted.

.PARAMETER Docker
    Switch to run the script inside a Docker container. When specified, the script will launch a Docker container
    using the given parameters and then exit.
    
.EXAMPLE
    .\Start-StaticBot.ps1 `
        -BotVolume "C:\g4-bots-volume" `
        -BotName "g4-static-bot" `
        -DriverBinaries "http://host.k8s.internal" `
        -HubUri "http://host.docker.internal:9944" `
        -IntervalTime 120 `
        -Token "your_token" `
        -RetentionThreshold 100 `
        -Docker
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

    # Calculate the next scheduled time by adding the specified interval to the current date and time.
    $nextAutomationTime = (Get-Date).AddSeconds($IntervalTime)

    # Format the calculated time in ISO 8601 format.
    $isoNextAutomation = $nextAutomationTime.ToString("o")

    # Display the custom message along with the formatted next invocation time.
    Write-Host "$Message $isoNextAutomation"

    # Pause execution for the specified interval.
    Start-Sleep -Seconds $IntervalTime
}

function Get-FreePort {
    <#
    .SYNOPSIS
    Finds and returns an available TCP port on the local machine.

    .DESCRIPTION
    Creates a temporary TCP listener bound to port 0, which instructs the OS
    to select an available port. Retrieves that port number, stops the listener,
    and returns the port for use in your scripts or services.

    .OUTPUTS
    System.Int32

    .EXAMPLE
    PS> $port = Get-FreePort
    PS> Write-Host "Starting server on port $port"
    #>
    [CmdletBinding()]
    param()

    # Create a TcpListener on the loopback interface with port 0 (OS picks a free port)
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 127.0.0.1)
    try {
        # Start listening (this allocates the port)
        $listener.Start()

        # Retrieve the assigned local endpoint and extract the port number
        $port = ($listener.LocalEndpoint).Port

        # Return the free port number
        return $port
    }
    finally {
        # Always stop the listener to free up the port
        $listener.Stop()
    }
}

function Start-Monitor {
    <#
    .SYNOPSIS
    Starts the G4 Bot Monitor process with configurable parameters.

    .DESCRIPTION
    The Start-Monitor function wraps the execution of the G4 Bot Monitor executable, handling both Windows and Unix platforms.
    It accepts parameters for the executable path, window style (Windows only), SignalR hub URI, bot listener URI, bot name, and bot type.
    On Windows, it applies the specified window style; on Unix, it launches the process normally.

    .PARAMETER MonitorFilePath
    Path to the G4 Bot Monitor executable file.

    .PARAMETER WindowStyle
    Window style for the process on Windows. Valid values are Normal, Hidden, Minimized, Maximized.

    .PARAMETER HubUri
    URI of the SignalR hub that the monitor will connect to.

    .PARAMETER BotUri
    URI of the bot listener endpoint that the monitor will host.

    .PARAMETER BotName
    Logical name under which this bot is registered with the hub.

    .PARAMETER BotType
    Type or category of the bot for hub registration.

    .PARAMETER BotId
    Unique identifier for this bot instance.

    .EXAMPLE
    PS> Start-Monitor -MonitorFilePath "C:\tools\g4-bot-monitor.exe" -HubUri "http://hub:9944" `
        -BotUri "http://localhost:8080/bot/v1/my-bot" -BotName "my-bot" -BotType "dynamic-bot" -BotId "bot123"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MonitorFilePath,

        [Parameter(Mandatory = $true)]
        [string]$HubUri,

        [Parameter(Mandatory = $true)]
        [string]$BotUri,

        [Parameter(Mandatory = $true)]
        [string]$BotName,

        [Parameter(Mandatory = $true)]
        [string]$BotType,

        [Parameter(Mandatory = $true)]
        [string]$BotId,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Normal","Hidden","Minimized","Maximized")]
        [string]$WindowStyle = "Normal"
    )

    # Build the full argument string for the monitor process
    $argumentList = @(
        "--HubUri=$($HubUri)"
        "--Name=`"$($BotName)`""
        "--Id=$($BotId)"
        "--Type=`"$($BotType)`""
        "--ListenerUri=$($BotUri)"
    ) -join ' '

    Start-Process -FilePath $MonitorFilePath -ArgumentList $argumentList -NoNewWindow -RedirectStandardOutput 'NUL'
    Write-Verbose "Launched monitor process '$($MonitorFilePath)' with arguments: $($argumentList)"

    # Compute when to stop pinging (10 seconds from now, UTC)
    $timeout    = [DateTime]::UtcNow.AddSeconds(10)

    # Build the full ping URI: e.g. http://.../monitor/{botId}/ping
    $monitorUri = "$($BotUri)/monitor/$($BotId)"

    # Track whether the monitor ever responded successfully
    $isMonitor  = $false

    # Retry loop until timeout
    Write-Host "Connecting monitor..."
    while ($timeout -gt [DateTime]::UtcNow) {
        try {
            # Attempt to ping the monitor endpoint
            $response = Invoke-RestMethod -Uri "$($monitorUri)/ping" -Method Get -ErrorAction Stop

            # Inform the user that the monitor is now running
            Write-Host "Monitor is connected and running at '$($monitorUri)'"
        }
        catch {
            # Suppress any network or HTTP errors and retry
            $response = $null
        }

        # If we got a valid HTTP response (<400), mark success and exit loop
        if ($response -and $response.StatusCode -lt 400) {
            $isMonitor = $true
            break
        }

        # Pause briefly before next attempt
        Start-Sleep -Milliseconds 500
    }

    # Warn if the monitor never became responsive
    if (-not $isMonitor) {
        Write-Warning "Monitor did not respond at '$($monitorUri)' within 10 seconds."
    }
}

function Update-BotStatus {
    <#
    .SYNOPSIS
    Sends a status update for the specified bot to the monitor endpoint.

    .DESCRIPTION
    The Update-BotStatus function constructs a JSON payload containing the bot’s ID and new status,
    then POSTs it to the monitor’s `/update` endpoint. On success, it notifies the user of the change.
    Any errors during the request are caught and suppressed.

    .PARAMETER BotId
    The unique identifier of the bot whose status is being updated.

    .PARAMETER MonitorUri
    The base URI of the monitor service (e.g., http://localhost:8080/bot/v1/my-bot).

    .PARAMETER Status
    The new status string to assign to the bot (e.g., "Running", "Stopped").

    .EXAMPLE
    PS> Update-BotStatus -BotId "bot123" -MonitorUri "http://localhost:8080/bot/v1/my-bot" -Status "Running"
    Sends a status update for bot123 indicating it is now Running.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BotId,

        [Parameter(Mandatory = $true)]
        [string]$MonitorUri,

        [Parameter(Mandatory = $true)]
        [string]$Status 
    )

    try {
        # Build the request body as compressed JSON: { "id": "<BotId>", "status": "<Status>" }
        $jsonBody = @{
            id     = $BotId
            status = $Status
        } | ConvertTo-Json -Compress

        # Send POST to the monitor's /update endpoint with JSON payload
        $response = Invoke-RestMethod `
            -Uri         "$MonitorUri/update" `
            -Method      Post `
            -ContentType "application/json; charset=utf-8" `
            -Body        $jsonBody `
            -ErrorAction Stop

        # Inform the user of successful update
        Write-Host "Successfully updated bot '$BotId' status to '$($Status)' at '$($MonitorUri)/update'."
    }
    catch {
        # Suppress errors but inform the user of failure
        Write-Warning "Failed to update status for bot '$BotId' to '$($Status)'. Monitor may be unreachable."
    }
}

if ($Docker) {
    try {
        Write-Verbose "Docker switch is enabled. Preparing to launch Docker container for bot '$($BotName)'."
        Write-Verbose "Building the Docker command from the specified parameters."
        $cmdLines = @(
            "run -d -v `"$($BotVolume):/bots`"",
            " -e BOT_NAME=`"$($BotName)`"",
            " -e DRIVER_BINARIES=`"$($DriverBinaries)`"",
            " -e HUB_URI=`"$($HubUri)`"",
            " -e INTERVAL_TIME=`"$($IntervalTime)`"",
            " -e TOKEN=`"$($Token)`"",
            " --name `"$($BotName)-$([guid]::NewGuid())`" g4-static-bot:latest"
        )
        
        Write-Verbose "Joining command parts into a single Docker command string."
        $dockerCmd = $cmdLines -join [string]::Empty

        Write-Host "Invoking Docker with the following command:$([System.Environment]::NewLine)docker $($dockerCmd)"
        $process = Start-Process -FilePath "docker" -ArgumentList $dockerCmd -PassThru
        $process.WaitForExit(60000)

        Write-Host "Docker container '$($BotName)' started successfully."
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

# Construct the full request URL by trimming any trailing slash from $HubUri and appending the endpoint path.
$requestUri = "$($HubUri.TrimEnd('/'))/api/v4/g4/automation/base64/invoke"

# Build the complete path to the bot's information directories
$botDirectory           = Join-Path $BotVolume $BotName
$botAutomationDirectory = Join-Path $botDirectory "bot"
$botFilePath            = Join-Path $botAutomationDirectory "automation.json"
$errorsDirectory        = [System.IO.Path]::Combine($BotVolume, $BotName, "errors")
$outputDirectory        = [System.IO.Path]::Combine($BotVolume, $BotName, "output")
$botId                  = "$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"

Clear-Host
Write-Host
Write-Host "Starting main bot loop.$([System.Environment]::NewLine)Press [Ctrl] + [C] to stop the script.$([System.Environment]::NewLine)"

# Detect Unix-based platforms
$monitorFilePath = Join-Path "bot-monitor" "g4-bot-monitor-windows.exe"
if([Environment]::OSVersion.Platform -eq [System.PlatformID]::Unix) {
    $monitorFilePath = Join-Path "bot-monitor" "g4-bot-monitor-windows"
}

$hostPort   = Get-FreePort
$botRoute   = "/bot/v1"
$botUri     = "http://localhost:$($HostPort)$($botRoute)/$($BotName)"
$monitorUri = "http://localhost:$($HostPort)$($botRoute)/$($BotName)/monitor/$($botId)"

Write-Host "Free TCP port found: $($hostPort)"

# Invoke the Start-Monitor function with all required parameters
Start-Monitor `
    -MonitorFilePath (Join-Path $PSScriptRoot $monitorFilePath) `
    -HubUri          $HubUri `
    -BotUri          $botUri `
    -BotName         $BotName `
    -BotType         "Static Bot" `
    -BotId           $botId

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
        $errorsPath = Join-Path $errorsDirectory "$($BotName)-$($session).json"
        
        # Read the entire content of 'automation.json' as raw text.
        $botFileContent = [System.IO.File]::ReadAllText($botFilePath, [System.Text.Encoding]::UTF8)

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

        # Update the bot status to 'Working'
        Update-BotStatus -BotId $botId -MonitorUri $monitorUri -Status "Working"

        # Send the Base64-encoded JSON to the remote endpoint using a POST request.
        Write-Host
        Write-Host "Sending Base64-encoded 'automation.json' to remote endpoint"
        $response = Invoke-RestMethod -Uri $requestUri -Method Post -Body $botContent -ContentType "text/plain"
    }
    catch {
        # If an error occurs, display a message and log the error details to the designated errors file.
        $baseException = $_.Exception.GetBaseException()
        Write-Error "An error occurred '$($baseException.Message)'.$([System.Environment]::NewLine)Check $errorsPath for details."
        @{ error = $baseException.StackTrace; message = $baseException.Message } | ConvertTo-Json -Compress | Out-File -FilePath $errorsPath -Force -ErrorAction Continue
    }
    finally {
        # Update the bot status to 'Ready'
        Update-BotStatus -BotId $botId -MonitorUri $monitorUri -Status "Ready"

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

    # Wait for the specified interval before starting the next iteration.
    Wait-Interval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
}
