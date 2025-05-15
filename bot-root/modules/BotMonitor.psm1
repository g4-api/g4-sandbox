# Import the bot logger utility modules
Import-Module (Join-Path $PSScriptRoot 'BotLogger.psm1') -Force

# Scriptblock to join a base URI and a relative path into a single normalized URI with exactly one '/' separator
$joinUri = {
    param($Base, $Path)

    # Trim any trailing slash from the base, trim any leading slash from the path,
    # then combine with a single '/' separator.
    $normalizedBase = $Base.TrimEnd('/')
    $normalizedPath = $Path.TrimStart('/')

    # Return the combined URI string
    return "$($normalizedBase)/$($normalizedPath)"
}

# Scriptblock to test hub availability by GETting the /api/v4/g4/ping endpoint and returning True on HTTP < 400
$pingUri = {
    param(
        [string]$Uri
    )

    try {
        # Send an HTTP GET to the ping endpoint
        $response = Invoke-WebRequest -Uri $Uri -Method Get -ErrorAction Stop

        # Return True if the HTTP status code is less than 400 (i.e. success)
        return $response.StatusCode -lt 400
    }
    catch {
        # On error (network failure, non-2xx/3xx status, etc.), return False
        return $false
    }
}

# Scriptblock to register a bot with the central hub
$registerBot = {
    param(
        $BotId,           # Unique identifier for the bot
        $BotName,         # Human-readable name of the bot
        $BotType,         # Type/category of the bot
        $CallbackIngress, # External ingress host or URL (e.g. host.docker.internal) used to route incoming callbacks to the bot
        $CallbackUri,     # Local listener URI (e.g. http://+:9213/) where the bot's HTTP listener receives callback requests
        $HubUri,          # Base URI of the central hub
        $Machine,         # Machine name or identifier where the bot runs
        $OsVersion        # Operating system version of the bot's host
    )

    # Initialize placeholders for HTTP response and message output
    $response = $null
    $message  = ''

    # Ensure HubUri has no trailing slash for consistent endpoint building
    $HubUri = $HubUri.TrimEnd('/')

    # Scriptblock to check whether the bot is already registered/active
    $isRegister = {
        param($StatusUri)

        try {
            # Perform GET request against the status endpoint
            $botStatus = Invoke-WebRequest -Uri $uri -Method Get

            # Return True if status is NOT one of the terminal states
            return $botStatus.status.ToUpper() -notin ("REMOVED", "LOCKED", "UNREACHABLE", "OFFLINE")
        }
        catch {
            # On any error (network, parsing, etc.), treat as not registered
            return $false
        }
    }

    try {
        # Build the URL to fetch the bot's current status
        $uri = "$($HubUri)/api/v4/g4/bots/status/$($BotId)"

        # Initialize the message for the "already registered" case
        $message = "Bot '$($BotName)' (ID: $($BotId)) is already registered and active at '$($uri)'."

        # If bot is already registered/active, return an HTTP-200-like result immediately
        if (& $isRegister -StatusUri $uri) {
            return [PSCustomObject]@{
                Value   = @{ StatusCode = 200 }
                Message = $message
            }
        }

        # Build the JSON payload for registration
        $body = @{
            callbackIngress = $CallbackIngress
            callbackUri     = $CallbackUri
            id              = $BotId
            machine         = $Machine
            name            = $BotName
            osVersion       = $OsVersion
            type            = $BotType
        } | ConvertTo-Json -Compress

        # Construct the registration endpoint URL
        $uri = "$($HubUri)/api/v4/g4/bots/register"

        # Send the registration POST request
        $response = Invoke-WebRequest `
            -Method      Post `
            -Uri         $uri `
            -Body        $body `
            -ContentType "application/json; charset=utf-8"

        # On success, prepare a descriptive confirmation message
        $message = "Bot '$($BotName)' (ID: $($BotId)) successfully registered at '$($uri)'."
    }
    catch {
        # If any exception occurs, capture its message for troubleshooting
        $message = "Failed to register bot '$($BotName)' (ID: $($BotId)) at '$($uri)'. Error: $($_.Exception.Message)"

        # Fallback to Internal Server Error (HTTP 500)
        $response = [PSCustomObject]@{ StatusCode = 500 }
    }

    # Return a standardized object with raw HTTP response and user-friendly message
    return [PSCustomObject]@{
        Value   = $response
        Message = $message
    }
}

# Scriptblock to start the bot's HTTP callback listener
$startBotCallbackListener = {   
    param(
        $BotId,    # Unique identifier for the bot; used to validate the callback path
        $HubUri,   # Base URI of the hub (unused here but available for future use)
        $Prefix    # The HTTP listener prefix (e.g. "http://+:8080/") where callbacks are received
    )

    # Determine the path to BotLogger.psm1 (assumes it's in the same folder as this script)
    $modulePath = Join-Path $PSScriptRoot 'BotLogger.psm1'

    # Build an InitialSessionState and import modules into it
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $iss.ImportPSModule('Microsoft.PowerShell.Utility')
    $iss.ImportPSModule($modulePath)

    # Create & open the runspace with that ISS
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    $runspace.Open()

    # Create a new in-process runspace for monitoring and registration logic
    $powerShell = [PowerShell]::Create()
    $powerShell.Runspace = $runspace

    # Create empty PSDataCollections for input/output (required by PS5 BeginInvoke signature)
    $inputBuffer  = [System.Management.Automation.PSDataCollection[PSObject]]::new()
    $outputBuffer = [System.Management.Automation.PSDataCollection[PSObject]]::new()

    # Relay warnings from the runspace
    $powerShell.Streams.Warning.add_DataAdded({
        param($s, $e)

        $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        [Console]::ForegroundColor = [ConsoleColor]::Yellow
        [Console]::WriteLine("$($timestamp) - WRN: (Start-BotCallbackListener) $($s[$e.Index].Message)")
        [Console]::ResetColor()
    })

    # Only wire up informational relaying if the session is configured to show Information streams
    if ($InformationPreference -eq 'Continue') {
        # Relay informational messages from the runspace
        $powerShell.Streams.Information.add_DataAdded({
            param($s, $e)

            $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            [Console]::WriteLine("$($timestamp) - INF: (Start-BotCallbackListener) $($s[$e.Index].MessageData)")
        })
    }

    # Define the listener logic, now accepting Prefix and BotId
    $powerShell.AddScript({
        param(
            $BotId,
            $Listener,
            $Prefix   
        )

        # Default to successful exit unless an error occurs
        $exitCode = 0

        try {
            # Add the listener prefix URI (e.g., http://*:54256/) to the listener
            $Listener.Prefixes.Add($Prefix) 

            # Start the HTTP listener to begin accepting requests
            $Listener.Start()

            # Enter the main loop to handle incoming HTTP requests
            while ($true) {
                # Wait for an incoming HTTP request and get the context
                $context = $listener.GetContext()

                # Reject requests from other bots sharing this listener port
                # Only allow requests whose path exactly matches /bot/v1/monitor/<BotId>
                if ($context.Request.Url.AbsolutePath -notcontains "/bot/v1/monitor/$($BotId)") {
                    Write-Warning "(Start-BotCallbackListener) Request path '$($context.Request.Url.AbsolutePath)' does not match '/bot/v1/monitor/$($BotId)'; Returning 403 Forbidden."
                    $context.Response.StatusCode = 403  # Forbidden
                    $context.Response.Close()
                    continue  # Continue listening for other requests
                }

                # Handle the request based on the HTTP method used
                switch ($context.Request.HttpMethod) {
                    'DELETE' {
                        # Client explicitly requested the bot to shut down
                        Write-Warning "Received DELETE on '/bot/v1/monitor/$($BotId)'; Shutting down..."
                        $context.Response.StatusCode = 204  # No Content
                        $context.Response.Close()
                        exit 0  # Exit successfully
                    }
                    'GET' {
                        # Health check ping
                        Write-Information "Health check received on '/bot/v1/monitor/$($BotId)'; Returning 200 OK."
                        $context.Response.StatusCode = 200  # OK
                        $context.Response.Close()
                        continue  # Continue listening
                    }
                    default {
                        # Any other HTTP method is not supported
                        Write-Warning "Unsupported HTTP method '$($context.Request.HttpMethod)' on '/bot/v1/monitor/$($BotId)'; Returning 405 Method Not Allowed."
                        $context.Response.StatusCode = 405  # Method Not Allowed
                        $context.Response.Close()
                    }
                }
            }
        }
        catch {
            # Define the expected message that signals a graceful listener shutdown
            $exitMessage = "The I/O operation has been aborted because of either a thread exit or an application request"

            # Determine whether the exception was caused by a graceful shutdown
            $isGraceful  = $_.Exception.Message.Contains('Exception calling "GetContext" with "0" argument(s)')

            if ($isGraceful) {
                # If it's a known graceful shutdown message, log and exit successfully
                Write-Information $exitMessage
                exit $exitCode
            }

            # Otherwise, log the unexpected error message and prepare to exit with an error
            Write-Warning "$($_.Exception.Message)"
            $exitCode = 1
        }
        finally {
            try {
                # Ensure the listener is stopped and closed, even if an error occurred
                if ($null -ne $Listener) {
                    $Listener.Stop()
                    $Listener.Close()
                }
            }
            catch {
                # Log cleanup issues at debug level since they are non-critical
                Write-Debug "(Start-BotCallbackListener) $($_.Exception.Message)"
            }
        }

        # Final logging based on how the process exited
        if ($exitCode -eq 0) {
            Write-Information "(Start-BotCallbackListener) Exiting gracefully with status 0"
        } else {
            Write-Warning "(Start-BotCallbackListener) Exiting due to unexpected error with status $($exitCode)"
        }

        # Exit with the appropriate status code
        exit $exitCode
    })

    # Initialize the callback http listener
    $listener = New-Object System.Net.HttpListener

    # Pass the Prefix and BotId arguments into the scriptblock
    $powerShell.AddArgument($BotId)
    $powerShell.AddArgument($listener)
    $powerShell.AddArgument($Prefix)
    
    # Start the runspace asynchronously, capturing the IAsyncResult
    $async = $powerShell.BeginInvoke($inputBuffer, $outputBuffer)

    # Return the runspace (Runner) and the async handle (AsyncResult) together
    return [PSCustomObject]@{
        Runner       = $powerShell
        AsyncResult  = $async
        InputBuffer  = $inputBuffer
        HttpListener = $listener
        OutputBuffer = $outputBuffer
    }
}

# Scriptblock to query a bot's status endpoint and return both the status and full response as a PSCustomObject
$testBotConnection = {
    param(
        [string]$Uri   # The endpoint URI to query for the bot's status
    )

    try {
        # Perform an HTTP GET; stop on non-success status codes
        $response = Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop

        # Build and return a standardized object with the bot's status and full response
        return [PSCustomObject]@{
            BotStatus = $response.status
            Response  = $response
        }
    }
    catch {
        # If anything goes wrong (network error or non-2xx status), return an error indicator
        return [PSCustomObject]@{
            BotStatus = "Error"
            Response  = [PSCustomObject]@{ message = $_.Exception.Message }
        }
    }
}

# Updates a bot's registration details (including status) at the central hub.
$updateBot = {
    param(
        $BotId,        # Unique identifier for the bot
        $BotName,      # Human-readable name for logging
        $BotType,      # Category/type of the bot
        $CallbackUri,  # URI where the bot receives callbacks
        $HubUri,       # Base URI of the central hub
        $Machine,      # Host machine name or ID
        $OsVersion,    # Operating system version of the host
        $Status        # New status to set for the bot
    )

    # Initialize placeholders for the HTTP response and result message
    $response = $null
    $message  = ''

    # Normalize HubUri by removing any trailing slash
    $HubUri = $HubUri.TrimEnd('/')

    try {
        # Build the JSON payload with all bot properties
        $body = @{
            callbackUri = $CallbackUri
            id          = $BotId
            machine     = $Machine
            name        = $BotName
            osVersion   = $OsVersion
            status      = $Status
            type        = $BotType
        } | ConvertTo-Json -Depth 5 -Compress

        # Construct the update endpoint URL
        $uri = "$HubUri/api/v4/g4/bots/register/$BotId"

        # Send the HTTP PUT request to update the bot
        $response = Invoke-WebRequest `
            -Method      Put `
            -Uri         $uri `
            -Body        $body `
            -ContentType "application/json; charset=utf-8" | Out-Null

        # On success, prepare a confirmation message
        $message = "Bot '$($BotName)' (ID: $($BotId)) updated successfully at '$($uri)' (HTTP $($response.StatusCode))."
    }
    catch {
        # On error, capture exception message for troubleshooting
        $message = "Failed to update bot '$($BotName)' (ID: $($BotId)) at '$($uri)'. Error: $($_.Exception.Message)"

        # Fallback response status code 500 for internal server error
        $response = [PSCustomObject]@{ StatusCode = 500 }
    }

    # Return a standardized object with the raw response and descriptive message
    return [PSCustomObject]@{
        Value   = $response
        Message = $message
    }
}

<#
.SYNOPSIS
    Registers the bot with the hub and starts its callback listener in the background.

.DESCRIPTION
    Start-BotCallbackListener attempts to register the specified bot at the central hub,
    then launches an in-process HTTP listener to handle callbacks at the given prefix.
    It will retry registration and listener startup until successful or until the timeout
    elapses, returning a PSCustomObject with the runspace and async handle on success,
    or $null on failure.

.PARAMETER BotCallbackUri
    Full URI where the bot will listen for callbacks (e.g. "http://localhost:8080/callback").

.PARAMETER BotCallbackPrefix
    HTTP listener prefix (including port and trailing slash) for monitoring callbacks
    (e.g. "http://+:8080/callback/").

.PARAMETER BotId
    Unique identifier for the bot, used in status checks and registration.

.PARAMETER BotName
    Human-readable name of the bot for logging and messaging.

.PARAMETER BotType
    Category or type of the bot, sent to the hub during registration.

.PARAMETER HubUri
    Base URI of the central hub for registration and status endpoints.

.PARAMETER Timeout
    Maximum number of seconds to retry registration and listener startup before giving up.

.EXAMPLE
    $job = Start-BotCallbackListener `
        -BotCallbackUri    "http://localhost:8080/callback" `
        -BotCallbackPrefix "http://+:8080/callback/" `
        -BotId             "abc123" `
        -BotName           "MyBot" `
        -BotType           "Worker" `
        -HubUri            "https://hub.example.com" `
        -Timeout           30

.NOTES
    - Depends on helper scriptblocks $registerBot and $startBotCallbackListener.
    - On success returns a PSCustomObject with properties:
        * Runner      � the PowerShell runspace instance
        * AsyncResult � the IAsyncResult token from BeginInvoke()
#>
function Start-BotCallbackListener {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BotCallbackIngress,
        [Parameter(Mandatory)][string] $BotCallbackUri,
        [Parameter(Mandatory)][string] $BotCallbackPrefix,
        [Parameter(Mandatory)][string] $BotId,
        [Parameter(Mandatory)][string] $BotName,
        [Parameter(Mandatory)][string] $BotType,
        [Parameter(Mandatory)][string] $HubUri,
        [Parameter(Mandatory)][int]    $Timeout
    )

    # Display startup banner and key endpoint information
    Start-Sleep -Seconds 3
    Write-Information ''                                                                    -Tags Endpoint -InformationAction Continue
    Write-Information '--- START BOT -------------'                                         -Tags Endpoint -InformationAction Continue
    Write-Information "Bot '$($BotName)' Endpoints"                                         -Tags Endpoint -InformationAction Continue
    Write-Information ''                                                                    -Tags Endpoint -InformationAction Continue
    Write-Information "Hub Ping URI:            $($HubUri)/api/v4/g4/ping"                  -Tags Endpoint -InformationAction Continue 
    Write-Information "Bot Status URI:          $($HubUri)/api/v4/g4/bots/status/$($BotId)" -Tags Endpoint -InformationAction Continue 
    Write-Information "Bot Callback Ingress:    $($BotCallbackIngress)"                     -Tags Endpoint -InformationAction Continue
    Write-Information "Bot Callback URI:        $($BotCallbackUri)"                         -Tags Endpoint -InformationAction Continue
    Write-Information "Monitor Endpoint Prefix: $($BotCallbackPrefix)"                      -Tags Endpoint -InformationAction Continue
    Write-Information '--- END -------------------'                                         -Tags Endpoint -InformationAction Continue
    Write-Information ''                                                                    -Tags Endpoint -InformationAction Continue

    # Determine when to stop retrying
    $expirationTime = [DateTime]::UtcNow.AddSeconds($Timeout)
    Write-Verbose "Startup will timeout at $($expirationTime) UTC."

    Write-Host "Callback listener initializing... please wait few seconds"
    while ([DateTime]::UtcNow -lt $expirationTime) {
        # 1) Try to register the bot with the hub
        Write-Verbose "Attempting to register bot '$BotName' (ID: $($BotId)) at '$($HubUri)'."
        $response = & $registerBot `
            -BotId           $BotId `
            -BotName         $BotName `
            -BotType         $BotType `
            -CallbackIngress $BotCallbackIngress `
            -CallbackUri     $BotCallbackUri `
            -HubUri          $HubUri `
            -Machine         ([Environment]::MachineName) `
            -OsVersion       ([Environment]::OSVersion.VersionString)

        # If registration failed (no response or HTTP >= 400), warn and retry
        if (-not $response.Value -or $response.Value.StatusCode -ge 400) {
            Write-Log -Level Warning -Message "(Start-BotCallbackListener) $($response.Message)" -UseColor
            Start-Sleep -Seconds 1
            continue
        }
        Write-Verbose $response.Message

        # 2) Start the callback listener asynchronously
        Write-Verbose "Starting background listener..."
        $callbackListenerJob = & $startBotCallbackListener `
            -BotId  $BotId `
            -HubUri $HubUri `
            -Prefix $BotCallbackPrefix

        # Grab the async token so we can check if it's running
        $async = $callbackListenerJob.AsyncResult

        # Allow a moment for the listener to spin up
        Start-Sleep -Seconds 3

        # 3) If listener is still running, return the job object to caller
        if (-not $async.IsCompleted) {
            return $callbackListenerJob
        }

        # Otherwise, the listener failed to initialize�warn and retry
        Write-Log -Level Warning -Message "(Start-BotCallbackListener) Listener startup did not begin as expected." -UseColor
        Write-Log -Level Verbose -Message "(Start-BotCallbackListener) Retrying listener startup." -UseColor
        Start-Sleep -Seconds 1
    }

    # Timeout reached without success
    Write-Log `
        -Level   Critical `
        -Message "(Start-BotCallbackListener) Idle bots are not allowed. Bot failed to register within $($Timeout) seconds�please verify hub connectivity at '$($HubUri)' and retry." `
        -UseColor
    if ($callbackListenerJob) {
        $callbackListenerJob.Dispose()
    }

    # Exit with error code to signal failure
    exit 1
}

<#
.SYNOPSIS
    Launches a background �watchdog� process to monitor and auto-register a bot.

.DESCRIPTION
    Start-WatchDog creates an in-process PowerShell runspace that continuously:
      1. Pings the central hub to verify connectivity.
      2. Checks the bot's current status (READY or WORKING).
      3. Registers the bot if it is not already active.
    This loop runs until the provided ParentTask completes or the timeout is reached.

.PARAMETER BotCallbackUri
    The HTTP callback URI where the bot listens for incoming notifications.

.PARAMETER BotCallbackPrefix
    The listener prefix (including port and trailing slash) for the bot's callback monitor.

.PARAMETER BotId
    Unique identifier for the bot, used in status checks and registration calls.

.PARAMETER BotName
    Human-readable name of the bot for logging and messaging.

.PARAMETER BotType
    Category or type of the bot, sent to the hub during registration.

.PARAMETER HubUri
    Base URI of the central hub service for pinging and registration.

.PARAMETER Timeout
    Maximum time (in seconds) to wait for initial registration before the function returns.

.PARAMETER PollingInterval
    Base interval (in seconds) between status checks and retry attempts (default: 30).

.PARAMETER ParentTask
    An object containing an AsyncResult; the watchdog loop exits when this task completes.

.EXAMPLE
    $task = Start-WatchDog `
        -BotCallbackUri    "http://localhost:8080/" `
        -BotCallbackPrefix "http://+:8080/" `
        -BotId             "abc123" `
        -BotName           "MyBot" `
        -BotType           "Worker" `
        -HubUri            "https://hub.example.com" `
        -Timeout           60 `
        -ParentTask        $myParent

.NOTES
    - Requires helper scriptblocks: $joinUri, $pingUri, $testBotConnection, $registerBot.  
    - Uses CmdletBinding to expose -Verbose and -Debug common parameters.
#>
function Start-BotWatchDog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BotCallbackIngress,
        [Parameter(Mandatory)][string] $BotCallbackUri,
        [Parameter(Mandatory)][string] $BotCallbackPrefix,
        [Parameter(Mandatory)][string] $BotId,
        [Parameter(Mandatory)][string] $BotName,
        [Parameter(Mandatory)][string] $BotType,
        [Parameter(Mandatory)][string] $HubUri,
        [Parameter(Mandatory)][int]    $Timeout,
        [Parameter()]         [int]    $PollingInterval = 30,
        [Parameter()]                  $ParentTask
    )

    # Determine the path to BotLogger.psm1 (assumes it's in the same folder as this script)
    $modulePath = Join-Path $PSScriptRoot 'BotLogger.psm1'

    # Build an InitialSessionState and import modules into it
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $iss.ImportPSModule('Microsoft.PowerShell.Utility')
    $iss.ImportPSModule($modulePath)

    # Create & open the runspace with that ISS
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    $runspace.Open()

    # Create a new in-process runspace for monitoring and registration logic
    $powerShell = [PowerShell]::Create()
    $powerShell.Runspace = $runspace

    # Create empty PSDataCollections for input/output (required by PS5 BeginInvoke signature)
    $inputBuffer  = [System.Management.Automation.PSDataCollection[PSObject]]::new()
    $outputBuffer = [System.Management.Automation.PSDataCollection[PSObject]]::new()

    # Relay warnings from the runspace
    $powerShell.Streams.Warning.add_DataAdded({
        param($s, $e)

        $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        [Console]::ForegroundColor = [ConsoleColor]::Yellow
        [Console]::WriteLine("$($timestamp) - WRN: (Start-BotWatchDog) $($s[$e.Index].Message)")
        [Console]::ResetColor()
    })

    # Only wire up informational relaying if the session is configured to show Information streams
    if ($InformationPreference -eq 'Continue') {
        # Relay informational messages from the runspace
        $powerShell.Streams.Information.add_DataAdded({
            param($s, $e)

            $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            [Console]::WriteLine("$($timestamp) - INF: (Start-BotWatchDog) $($s[$e.Index].MessageData)")
        })
    }

    # Add the script to the runspace, passing in all helper scriptblocks and parameters
    $powerShell.AddScript({      
        param(
            $BotCallbackIngress, # External ingress host or URL (e.g. host.docker.internal) used to route incoming callbacks to the bot
            $BotCallbackUri,     # HTTP callback URI for bot notifications            
            $BotId,              # Unique identifier for this bot
            $BotName,            # Human-readable bot name
            $BotType,            # Category/type of the bot
            $HubUri,             # Base URI of the central hub service
            $PollingInterval,    # Base interval (seconds) for polling/backoff
            $ParentTask
        )

        # Scriptblock to join a base URI and a relative path into a single normalized URI with exactly one '/' separator
        $JoinUri = {
            param($Base, $Path)

            # Trim any trailing slash from the base, trim any leading slash from the path,
            # then combine with a single '/' separator.
            $normalizedBase = $Base.TrimEnd('/')
            $normalizedPath = $Path.TrimStart('/')

            # Return the combined URI string
            return "$($normalizedBase)/$($normalizedPath)"
        }

        # Scriptblock to test hub availability by GETting the /api/v4/g4/ping endpoint and returning True on HTTP < 400
        $PingUri = {
            param(
                [string]$Uri
            )

            try {
                # Send an HTTP GET to the ping endpoint
                $response = Invoke-WebRequest -Uri $Uri -Method Get -ErrorAction Stop

                # Return True if the HTTP status code is less than 400 (i.e. success)
                return $response.StatusCode -lt 400
            }
            catch {
                # On error (network failure, non-2xx/3xx status, etc.), return False
                return $false
            }
        }

        # Scriptblock to query a bot's status endpoint and return both the status and full response as a PSCustomObject
        $TestBotConnection = {
            param(
                [string]$Uri   # The endpoint URI to query for the bot's status
            )

            try {
                # Perform an HTTP GET; stop on non-success status codes
                $response = Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop

                # Build and return a standardized object with the bot's status and full response
                return [PSCustomObject]@{
                    BotStatus = $response.status
                    Response  = $response
                }
            }
            catch {
                # If anything goes wrong (network error or non-2xx status), return an error indicator
                return [PSCustomObject]@{
                    BotStatus = "Error"
                    Response  = [PSCustomObject]@{ message = $_.Exception.Message }
                }
            }
        }

        # Scriptblock to register a bot with the central hub
        $RegisterBot = {
            param(
                $BotId,           # Unique identifier for the bot
                $BotName,         # Human-readable name of the bot
                $BotType,         # Type/category of the bot
                $CallbackIngress, # External ingress host or URL (e.g. host.docker.internal) used to route incoming callbacks to the bot
                $CallbackUri,     # Local listener URI (e.g. http://+:9213/) where the bot's HTTP listener receives callback requests
                $HubUri,          # Base URI of the central hub
                $Machine,         # Machine name or identifier where the bot runs
                $OsVersion        # Operating system version of the bot's host
            )

            # Initialize placeholders for HTTP response and message output
            $response = $null
            $message  = ''

            # Ensure HubUri has no trailing slash for consistent endpoint building
            $HubUri = $HubUri.TrimEnd('/')

            # Scriptblock to check whether the bot is already registered/active
            $isRegister = {
                param($StatusUri)

                try {
                    # Perform GET request against the status endpoint
                    $botStatus = Invoke-WebRequest -Uri $uri -Method Get

                    # Return True if status is NOT one of the terminal states
                    return $botStatus.status.ToUpper() -notin ("REMOVED", "LOCKED", "UNREACHABLE", "OFFLINE")
                }
                catch {
                    # On any error (network, parsing, etc.), treat as not registered
                    return $false
                }
            }

            try {
                # Build the URL to fetch the bot's current status
                $uri = "$($HubUri)/api/v4/g4/bots/status/$($BotId)"

                # Initialize the message for the "already registered" case
                $message = "Bot '$($BotName)' (ID: $($BotId)) is already registered and active at '$($uri)'."

                # If bot is already registered/active, return an HTTP-200-like result immediately
                if (& $isRegister -StatusUri $uri) {
                    return [PSCustomObject]@{
                        Value   = @{ StatusCode = 200 }
                        Message = $message
                    }
                }

                # Build the JSON payload for registration
                $body = @{
                    callbackIngress = $CallbackIngress
                    callbackUri     = $CallbackUri
                    id              = $BotId
                    machine         = $Machine
                    name            = $BotName
                    osVersion       = $OsVersion
                    type            = $BotType
                } | ConvertTo-Json -Compress

                # Construct the registration endpoint URL
                $uri = "$($HubUri)/api/v4/g4/bots/register"

                # Send the registration POST request
                $response = Invoke-WebRequest `
                    -Method      Post `
                    -Uri         $uri `
                    -Body        $body `
                    -ContentType "application/json; charset=utf-8"

                # On success, prepare a descriptive confirmation message
                $message = "Bot '$($BotName)' (ID: $($BotId)) successfully registered at '$($uri)'."
            }
            catch {
                # If any exception occurs, capture its message for troubleshooting
                $message = "Failed to register bot '$($BotName)' (ID: $($BotId)) at '$($uri)'. Error: $($_.Exception.Message)"

                # Fallback to Internal Server Error (HTTP 500)
                $response = [PSCustomObject]@{ StatusCode = 500 }
            }

            # Return a standardized object with raw HTTP response and user-friendly message
            return [PSCustomObject]@{
                Value   = $response
                Message = $message
            }
        }

        # Enable verbose and information streams for detailed logging
        $DebugPreference       = 'Continue'
        $InformationPreference = 'Continue'
        $VerbosePreference     = 'Continue'
        
        # Build full URIs for hub ping and bot status check
        $hubPingUri = & $JoinUri $HubUri "/api/v4/g4/ping"
        $statusUri  = & $JoinUri $HubUri "/api/v4/g4/bots/test/$($BotId)"

        # Infinite loop to continuously monitor and (re)register the bot until the script is terminated
        while (-not $ParentTask.AsyncResult.IsCompleted -or $ParentTask.Runner.InvocationStateInfo.State -ne 'Completed') {
            try {
                # 1. Ping the hub: if it fails, warn and back off
                if (-not (& $PingUri -Uri $hubPingUri)) {
                    Write-Warning "Ping to '$($hubPingUri)' failed. Waiting $($PollingInterval) seconds before retry."
                    Start-Sleep -Seconds $PollingInterval
                    continue
                }

                # 2. Check the bot's current state: skip registration if already READY/WORKING
                $statusResult = & $TestBotConnection -Uri $statusUri
                if ($statusResult.BotStatus.ToUpper() -in 'READY','WORKING') {
                    Write-Information "Bot at '$($statusUri)' is '$($statusResult.BotStatus)'; Skipping Registration."
                    Start-Sleep -Seconds $PollingInterval
                    continue
                }

                # 3. Register the bot: log, invoke helper, then check HTTP response
                Write-Information "Registering bot '$($BotName)' (ID: $($BotId)) at '$($HubUri)'..."
                $response = & $RegisterBot `
                    -BotId           $BotId `
                    -BotName         $BotName `
                    -BotType         $BotType `
                    -CallbackIngress $BotCallbackIngress `
                    -CallbackUri     $BotCallbackUri `
                    -HubUri          $HubUri `
                    -Machine         ([Environment]::MachineName) `
                    -OsVersion       ([Environment]::OSVersion.VersionString)

                # 4. On failure (no response or StatusCode >= 400), warn and retry
                if (-not $response.Value -or $response.Value.StatusCode -ge 400) {
                    Write-Warning "Registration to '$($HubUri)' failed. Waiting $($PollingInterval) seconds before retry."
                    Write-Warning $message
                    Start-Sleep -Seconds $PollingInterval
                    continue
                }

                # 5. On success, inform
                Write-Information "Bot '$($BotName); $($BotId)' successfully registered."
            }
            catch {
                Write-Warning "$($_)"
                Start-Sleep -Seconds $PollingInterval
            }
        }
    })

    # Add arguments matching the runspace script's param() order
    $powerShell.AddArgument($BotCallbackIngress)
    $powerShell.AddArgument($BotCallbackUri)
    $powerShell.AddArgument($BotId)
    $powerShell.AddArgument($BotName)
    $powerShell.AddArgument($BotType)
    $powerShell.AddArgument($HubUri)
    $powerShell.AddArgument($PollingInterval)
    $powerShell.AddArgument($ParentTask)

    # Start the runspace asynchronously, capturing the IAsyncResult
    $async = $powerShell.BeginInvoke($inputBuffer, $outputBuffer)

    # Allow a moment for the listener to spin up
    Write-Host "Watchdog initializing... please wait few seconds"
    Start-Sleep -Seconds 3

    # Return the runspace, async token, and buffers for monitoring and cleanup
    return [PSCustomObject]@{
        Runner       = $powerShell
        AsyncResult  = $async
        InputBuffer  = $inputBuffer
        OutputBuffer = $outputBuffer
    }
}

<#
.SYNOPSIS
    Updates a bot's status on the central hub if it is currently in a valid state.

.DESCRIPTION
    Update-BotStatus first checks the bot's current status via the Test-BotConnection helper.
    If the bot is not in �READY� or �WORKING� states, it emits a warning and does nothing.
    Otherwise, it calls the Update-Bot helper to send an HTTP PUT updating the bot's status.

.PARAMETER BotId
    Unique identifier of the bot to update.

.PARAMETER HubUri
    Base URI of the central hub service (e.g. "https://hub.example.com").

.PARAMETER Status
    The new status value to set for the bot (e.g. "Working", "Stopped").

.EXAMPLE
    # Only updates if the bot is READY or WORKING
    Update-BotStatus -BotId "abc123" -HubUri "https://hub.example.com" -Status "Working"
#>
function Update-BotStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BotId,
        [Parameter(Mandatory)][string] $HubUri,
        [Parameter(Mandatory)][string] $Status
    )

    # Scriptblock to join a base URI and a relative path into a single normalized URI with exactly one '/' separator
    $joinUri = {
        param($Base, $Path)

        # Trim any trailing slash from the base, trim any leading slash from the path,
        # then combine with a single '/' separator.
        $normalizedBase = $Base.TrimEnd('/')
        $normalizedPath = $Path.TrimStart('/')

        # Return the combined URI string
        return "$($normalizedBase)/$($normalizedPath)"
    }

    # Updates a bot's registration details (including status) at the central hub.
    $updateBot = {
        param(
            $BotId,        # Unique identifier for the bot
            $BotName,      # Human-readable name for logging
            $BotType,      # Category/type of the bot
            $CallbackUri,  # URI where the bot receives callbacks
            $HubUri,       # Base URI of the central hub
            $Machine,      # Host machine name or ID
            $OsVersion,    # Operating system version of the host
            $Status        # New status to set for the bot
        )

        # Initialize placeholders for the HTTP response and result message
        $response = $null
        $message  = ''

        # Normalize HubUri by removing any trailing slash
        $HubUri = $HubUri.TrimEnd('/')

        try {
            # Build the JSON payload with all bot properties
            $body = @{
                callbackUri = $CallbackUri
                id          = $BotId
                machine     = $Machine
                name        = $BotName
                osVersion   = $OsVersion
                status      = $Status
                type        = $BotType
            } | ConvertTo-Json -Depth 5 -Compress

            # Construct the update endpoint URL
            $uri = "$HubUri/api/v4/g4/bots/register/$BotId"

            # Send the HTTP PUT request to update the bot
            $response = Invoke-WebRequest `
                -Method      Put `
                -Uri         $uri `
                -Body        $body `
                -ContentType "application/json; charset=utf-8"

            # On success, prepare a confirmation message
            $message = "Bot '$($BotName)' (ID: $($BotId)) updated successfully at '$($uri)' (HTTP $($response.StatusCode))."
        }
        catch {
            # On error, capture exception message for troubleshooting
            $message = "Failed to update bot '$($BotName)' (ID: $($BotId)) at '$($uri)'. Error: $($_.Exception.Message)"

            # Fallback response status code 500 for internal server error
            $response = [PSCustomObject]@{ StatusCode = 500 }
        }

        # Return a standardized object with the raw response and descriptive message
        return [PSCustomObject]@{
            Value   = $response
            Message = $message
        }
    }

    # Construct the URI to test the bot's current status
    $statusUri    = & $joinUri -Base $HubUri -Path "/api/v4/g4/bots/test/$($BotId)"
    
    # Invoke the Test-BotConnection helper to retrieve the bot's status
    $statusResult = & $testBotConnection -Uri $statusUri

    # If the bot is not in READY or WORKING, warn and exit
    if ($statusResult.BotStatus.ToUpper() -notin 'READY','WORKING') {
        return [PSCustomObject]@{
            Value   = [PSCustomObject]@{ StatusCode = 500 }
            Message = "Bot '$($BotId)' is in state '$($statusResult.BotStatus)'; Status update skipped."
        }
    }

    # Call the Update-Bot helper with all required parameters
    $response = & $updateBot `
        -BotId       $BotId `
        -BotName     $statusResult.Response.name `
        -BotType     $statusResult.Response.type `
        -CallbackUri $statusResult.Response.callbackUri `
        -HubUri      $HubUri `
        -Machine     ([Environment]::MachineName) `
        -OsVersion   ([Environment]::OSVersion.VersionString) `
        -Status      $Status

    # Return the raw response object (and let the caller inspect response.StatusCode/message)
    return $response
}

Export-ModuleMember -Function Start-BotCallbackListener
Export-ModuleMember -Function Start-BotWatchDog
Export-ModuleMember -Function Update-BotStatus