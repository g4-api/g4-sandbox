param (
    [CmdletBinding()]
    [Parameter(Mandatory = $false)] [string] $Base64ResponseContent,
    [Parameter(Mandatory = $false)] [string] $BotId,
    [Parameter(Mandatory = $true)]  [string] $BotName,
    [Parameter(Mandatory = $true)]  [string] $BotVolume,
    [Parameter(Mandatory = $false)] [string] $CallbackIngress,
    [Parameter(Mandatory = $false)] [string] $CallbackUri,
    [Parameter(Mandatory = $false)] [string] $ContentType,
    [Parameter(Mandatory = $true)]  [string] $DriverBinaries,
    [Parameter(Mandatory = $false)] [string] $EntryPointIngress,
    [Parameter(Mandatory = $false)] [string] $EntryPointUri,
    [Parameter(Mandatory = $true)]  [string] $HubUri,
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

# Set default values
$Base64ResponseContent = if([string]::IsNullOrEmpty($Base64ResponseContent)) { "eyJtZXNzYWdlIjoic3VjY2VzcyJ9" }    else { $Base64ResponseContent }
$ContentType           = if([string]::IsNullOrEmpty($ContentType))           { "application/json; charset=utf-8" } else { $ContentType }

# Build the bot's configuration object (endpoints, metadata, timeouts)
$botConfiguration = New-BotConfiguration `
    -BotId               $BotId `
    -BotName             $BotName `
    -BotType             'post-http-bot' `
    -BotVolume           $BotVolume `
    -CallbackIngress     $CallbackIngress `
    -CallbackUri         $CallbackUri `
    -DriverBinaries      $DriverBinaries `
    -EntryPointIngress   $EntryPointIngress `
    -EntryPointUri       $EntryPointUri `
    -EnvironmentFilePath (Join-Path $PSScriptRoot ".env") `
    -HubUri              $HubUri `
    -Token               $Token

# Only proceed if Docker support is enabled
if ($Docker) {
    try {
        #. $botLoggerModulePath
        Write-Log -Level Verbose -UseColor -Message "Docker switch is enabled. Preparing to launch Docker container for bot '$($botConfiguration.Metadata.BotName)'."
        Write-Log -Level Verbose -UseColor -Message "Building the Docker command from the specified parameters."

        # Initialize an array of docker run arguments
        $cmdLines = @(
            "run -d -v `"$($botConfiguration.Directories.BotVolume):/bots`""
            " -e BASE64_RESPONSE_CONTENT=`"$($Base64ResponseContent)`""
            " -e BOT_ID=`"$($botConfiguration.Metadata.BotId)`""
            " -e BOT_NAME=`"$($BotName)`""
            " -e CALLBACK_INGRESS=`"$($CallbackIngress)`""
            " -e CALLBACK_URI=`"$($CallbackUri)`""
            " -e CONTENT_TYPE=`"$($ContentType)`""
            " -e DRIVER_BINARIES=`"$($DriverBinaries)`""
            " -e ENTRY_POINT_INGRESS=`"$($EntryPointIngress)`""
            " -e ENTRY_POINT_URI=`"$($EntryPointUri)`""
            " -e HUB_URI=`"$($HubUri)`""
            " -e SAVE_ERRORS=`"$($botConfiguration.Settings.SaveErrors)`""
            " -e SAVE_RESPONSE=`"$($botConfiguration.Settings.SaveResponse)`""
            " -e TOKEN=`"$($Token)`""
        )

        # Optionally add SAVE_OUTPUT flag when requested
        $cmdLines += if ($SaveOutput) { " -e SAVE_OUTPUT=`"true`"" }

        # Publish port entry point port
        $cmdLines += " -p $($botConfiguration.Endpoints.EntryPointPort):$($botConfiguration.Endpoints.EntryPointPort)"
        
        # Publish port and assign unique container name
        $cmdLines += " -p $($botConfiguration.Endpoints.CallbackPort):$($botConfiguration.Endpoints.CallbackPort)"

        # Set container name and tag
        $cmdLines += " --name `"$($botConfiguration.Metadata.BotName)-$([guid]::NewGuid())`" g4-http-post-listener-bot:latest"

        # Combine the array of arguments into one continuous string
        Write-Log -Level Verbose -UseColor -Message "Joining command parts into a single Docker command string."
        $dockerCmd = $cmdLines -join [string]::Empty

        # Wait up to 60 seconds for the container to start
        Write-Log -Level Verbose -UseColor -Message "Invoking Docker with the following command:$([System.Environment]::NewLine)docker $($dockerCmd)"
        $process = Start-Process -FilePath "docker" -ArgumentList $dockerCmd -PassThru
        $process.WaitForExit(60000)
    }
    catch {
        # Report error details on failure
        Write-Log -Level Critical -UseColor -Message "Failed to start Docker container '$($BotName)': $($_.Exception.GetBaseException())"
        
    }
    finally{
        Exit 1
    }
}

# Build the bot configuration object with endpoints, metadata, and timeouts
$bot               = Initialize-BotByConfiguration -BotConfiguration $botConfiguration
$botBase64Content  = $botConfiguration.Metadata.BotBase64Content
$botCalculatedName = $botConfiguration.Metadata.BotName
$botEntryPoint     = $botConfiguration.Endpoints.BotEntryPointPrefix
$errorsDirectory   = $botConfiguration.Directories.BotErrorsDirectory
$instance          = $botConfiguration.Metadata.BotId
$outputDirectory   = $botConfiguration.Directories.BotOutputDirectory
$saveErrors        = $botConfiguration.Settings.SaveErrors
$saveResponse      = $botConfiguration.Settings.SaveResponse

# Definitions: grab the ScriptBlock for each function so they can be injected into a child runspace
$formatParameters = {
    param($BotName, $Request, $NewGenericError, $TestJson)

    try {
        # Read the raw JSON payload from the request body using the specified encoding
        $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
        $json   = $reader.ReadToEnd()

        try {
            # Attempt to parse the raw string as a JSON object
            $jsonObject = $json | ConvertFrom-Json
        }
        catch {
            # If parsing fails, return a 400 Bad Request with a detailed error message
            return & $NewGenericError `
                -Exception  $_.Exception `
                -StatusCode 400 `
                -Title      "Invalid JSON" `
                -Controller $BotName `
                -Action     "Invoke"
        }

        # Validate that the parsed JSON is a non-empty object with at least one property
        if (-not (& $TestJson -JsonString $json)) {
            # Return a 400 Bad Request if the JSON is empty or only contains a primitive
            $message = "The JSON object must contain at least one property and cannot consist solely of primitive values (e.g., strings, numbers, etc.)."
            return & $NewGenericError `
                -Exception  (New-Object System.Exception $message) `
                -StatusCode 400 `
                -Title      "Invalid JSON" `
                -Controller $BotName `
                -Action     "Invoke"
        }

        # Convert the original JSON string into a PowerShell object, then re-serialize it into minified JSON
        $dataObject   = $json       | ConvertFrom-Json
        $minifiedJson = $dataObject | ConvertTo-Json -Depth 50 -Compress

        # Wrap the JSON in an array if it’s not already formatted as one
        if (-not ($minifiedJson.StartsWith("[") -and $minifiedJson.EndsWith("]"))) {
            $minifiedJson = "[$($minifiedJson)]"
        }

        # Return a 200 OK status along with the (possibly transformed) JSON string
        return @{ StatusCode = 200; Value = $minifiedJson }
    }
    catch {
        # If any unexpected error occurs, return a 500 Internal Server Error
        return & $NewGenericError `
            -Exception  $_.Exception `
            -StatusCode 400 `
            -Title      "Invalid JSON" `
            -Controller $BotName `
            -Action     "Invoke"
    }
}
$newGenericError          = (Get-Command -Name 'New-GenericError').ScriptBlock
$sendBotAutomationRequest = (Get-Command -Name 'Send-BotAutomationRequest').ScriptBlock
$setJsonData              = (Get-Command -Name 'Set-JsonData').ScriptBlock
$testJson                 = (Get-Command -Name 'Test-Json').ScriptBlock
$updateBotStatus          = (Get-Command -Name 'Update-BotStatus').ScriptBlock
$writeResponse            = (Get-Command -Name 'Write-Response').ScriptBlock

# Build an InitialSessionState and import modules into it
$iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

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
        [Console]::WriteLine("$($timestamp) - WRN: (Start-HttpStaticListenerBot) $($s[$e.Index].Message)")
        [Console]::ResetColor()
    })

# Only wire up informational relaying if the session is configured to show Information streams
if ($InformationPreference -eq 'Continue') {
        # Relay informational messages from the runspace
        $powerShell.Streams.Information.add_DataAdded({
            param($s, $e)

            $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            [Console]::WriteLine("$($timestamp) - INF: (Start-HttpStaticListenerBot) $($s[$e.Index].MessageData)")
        })
    }

# Add the script to the runspace, passing in all helper scriptblocks and parameters
$powerShell.AddScript({
    param(
        $Base64ResponseContent,
        $BotBase64Content,
        $BotEntryPoint,
        $BotId,
        $BotName,
        $ContentType,
        $ErrorsDirectory,
        $FormatParameters,
        $HubUri,
        $NewGenericError,
        $OutputDirectory,
        $SaveErrors,
        $SaveResponse,
        $SendBotAutomationRequest,
        $SetJsonData,
        $TestJson,
        $UpdateBotStatus,
        $WriteResponse,
        $Listener
    )

    try {
        # Enable debug, information, and verbose output for troubleshooting
        $DebugPreference       = 'Continue'
        $InformationPreference = 'Continue'
        $VerbosePreference     = 'Continue'

        # Add the main ingress URL and the /ping endpoint to listen on
        $Listener.Prefixes.Add("$($BotEntryPoint.TrimEnd('/'))/")
        $Listener.Prefixes.Add("$($BotEntryPoint.TrimEnd('/'))/ping/")
    
        # Begin listening for HTTP requests
        $Listener.Start()

        # Continue looping until the parent task completes
        while ($true) {
            # Wait for the next incoming HTTP context
            $context  = $Listener.GetContext()
            $request  = $context.Request    # The incoming HTTP request
            $response = $context.Response   # The HTTP response to send back

            # Generate a unique session ID based on current timestamp
            $session = (Get-Date).ToString("yyyyMMddHHmmssfff")

            # Build file paths for saving output and errors
            $outputFilePath = [IO.Path]::Combine($OutputDirectory, "$($BotName)-$($session).json")
            $errorFilePath  = [IO.Path]::Combine($ErrorsDirectory, "$($BotName)-$($session).json")

            # Handle CORS preflight (OPTIONS) requests
            if ($request.HttpMethod.ToUpper() -eq "OPTIONS") {
                $response.StatusCode = 200
                $response.Headers.Add("Access-Control-Allow-Origin", "*")
                $response.Headers.Add("Access-Control-Allow-Methods", "GET, OPTIONS")
                $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
                $response.Close()
            
                # Skip further processing for OPTIONS
                continue
            }

            # Handle health-check /ping endpoint
            if ($request.RawUrl -match '(?i)/ping(?:/)?(?:\?.*)?$') {
                & $WriteResponse `
                    -Response              $response `
                    -Base64ResponseContent "eyJtZXNzYWdlIjoicG9uZyJ9"
            
                # Skip bot processing for ping
                continue  
            }

            # Reject any method other than GET
            if ($request.HttpMethod.ToUpper() -ne "POST") {
                # Create an HTTP request exception indicating the method is not allowed
                $error405 = & $NewGenericError `
                    -Exception  (New-Object System.Exception "Only POST requests are accepted") `
                    -StatusCode 405 `
                    -Title      'Method Not Allowed' `
                    -Controller $BotName `
                    -Action     'Invoke' `
                    -TraceId    "$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
                    
                # Send the serialized error response with status code 405
                & $WriteResponse `
                    -Response               $response `
                    -Base64ResponseContent  $error405.Base64Value `
                    -StatusCode             405

                # Skip further processing for this request since it used an invalid method
                continue
            }

            # Warn if any query parameters were sent (we ignore them)
            if ($request.QueryString.Count -gt 0) {
                Write-Warning "Detected query string parameters. These parameters will be ignored by the listener"
            }
            
            # Notify the hub that the bot is working on a new request
            & $UpdateBotStatus -BotId $BotId -HubUri $HubUri -Status "Working" | Out-Null

            # Format incoming request parameters into a JSON-compatible structure
            # This handles parsing and validation of the request body and returns a structured result
            $parametersResult = (& $formatParameters `
                -BotName         $BotName `
                -Request         $request `
                -NewGenericError $NewGenericError `
                -TestJson        $TestJson)

            # If the formatting/validation failed (non-200 status), send error response and exit early
            if ($parametersResult.StatusCode -ne 200) {
                & $WriteResponse `
                    -Response               $response `
                    -Base64ResponseContent  $parametersResult.Base64Value `
                    -StatusCode             $parametersResult.StatusCode

                # Skip further processing for this request since it resulted in an error
                continue
            }

            # Inject the formatted JSON data into the base64-encoded automation request
            # This returns a new Base64-encoded automation request with updated .dataSource field
            $BotBase64Content = & $SetJsonData -Base64AutomationRequest $BotBase64Content -JsonData $parametersResult.Value

            # Send the automation request to the bot and capture its response
            $botResponse = & $SendBotAutomationRequest `
                -HubUri         $HubUri `
                -Base64Request  $BotBase64Content

            # Normalize status code to a string array, even if it's just one item
            $statusCodes = @(@($botResponse.StatusCode) | Where-Object { -not [string]::IsNullOrWhiteSpace("$($_)") })

            # Safely pick last valid status code
            if ($statusCodes.Length -gt 0) {
                $botStatusCodeValue = "$($statusCodes[-1])"
            } else {
                Write-Warning "Status code array contains only empty/null values. Falling back to status code 500."
                $botStatusCodeValue = "500"
            }

            # Try parsing explicitly
            $botStatusCode = 0
            if (-not [int]::TryParse($botStatusCodeValue, [ref]$botStatusCode)) {
                Write-Warning "Failed parsing status code from: $($botStatusCodeValue). Falling back to status code 500."
            }

            # Normalize status code to if failed to parse
            $botStatusCode = if($botStatusCode -eq 0) { 500 } else { $botStatusCode }

            # If the bot returned an error and we should save errors, write to error file
            if ($botStatusCode -ge 400 -and $SaveErrors) {
                Set-Content -Value $botResponse.JsonValue -Path $errorFilePath
                $bytes                 = [System.Text.Encoding]::UTF8.GetBytes($botResponse.JsonValue)
                $Base64ResponseContent = [System.Convert]::ToBase64String($bytes)
            }

            # If the bot succeeded and we should save responses, write to output file
            if ($botStatusCode -eq 200 -and $SaveResponse) {
                Set-Content -Value $botResponse.JsonValue -Path $outputFilePath
            }
       
            # Choose response Content-Type: use bot’s type for error bodies, default otherwise
            $responseContentType = if ($botStatusCode -gt 204) {
                $botResponse.ContentType
            } else {
                $ContentType
            }

            # Write the final HTTP response back to the caller
            & $WriteResponse `
                -Response              $response `
                -Base64ResponseContent $Base64ResponseContent `
                -ContentType           $responseContentType `
                -StatusCode            $botStatusCode

            # Notify the hub that the bot is now ready for a new request
            & $UpdateBotStatus -BotId $BotId -HubUri $HubUri -Status "Ready" | Out-Null
        }

        # After loop exits, stop and close the listener
        $Listener.Stop()
        $Listener.Close()
    }
    catch {
        # Log the exception message as a warning
        if(-not $_.Exception.Message.Contains('The I/O operation has been aborted because of either a thread exit or an application request')) {
            Write-Warning $_.Exception.Message
        }
    
        # Notify the hub that the bot is now offline and cannot accept new requests
        & $UpdateBotStatus -BotId $BotId -HubUri $HubUri -Status "Offline" | Out-Null
    
        # Issue a specific warning indicating the I/O operation was aborted (common during thread exit or shutdown)
        Write-Warning "The I/O operation has been aborted because of either a thread exit or an application request"
    }
}) | Out-Null

# Initialize the bot HTTP listener
$listener = New-Object System.Net.HttpListener

# Add arguments matching the runspace script's param() order
$powerShell.AddArgument($Base64ResponseContent)    | Out-Null
$powerShell.AddArgument($botBase64Content)         | Out-Null
$powerShell.AddArgument($botEntryPoint)            | Out-Null
$powerShell.AddArgument($instance)                 | Out-Null
$powerShell.AddArgument($botCalculatedName)        | Out-Null
$powerShell.AddArgument($ContentType)              | Out-Null
$powerShell.AddArgument($errorsDirectory)          | Out-Null
$powerShell.AddArgument($formatParameters)         | Out-Null
$powerShell.AddArgument($HubUri)                   | Out-Null
$powerShell.AddArgument($newGenericError)          | Out-Null
$powerShell.AddArgument($outputDirectory)          | Out-Null
$powerShell.AddArgument($saveErrors)               | Out-Null
$powerShell.AddArgument($saveResponse)             | Out-Null
$powerShell.AddArgument($sendBotAutomationRequest) | Out-Null
$powerShell.AddArgument($setJsonData)              | Out-Null
$powerShell.AddArgument($testJson)                 | Out-Null
$powerShell.AddArgument($updateBotStatus)          | Out-Null
$powerShell.AddArgument($writeResponse)            | Out-Null
$powerShell.AddArgument($listener)                 | Out-Null

# Start the runspace asynchronously, capturing the IAsyncResult
$async = $powerShell.BeginInvoke($inputBuffer, $outputBuffer)

# Allow a moment for the listener to spin up
Write-Host "Bot HTTP listener initializing... please wait few seconds"
Start-Sleep -Seconds 3

Write-Host "`nListening for incoming http requests for bot '$($BotName)' on uri '$($botEntryPoint)'.`nPress [Ctrl] + [C] to stop the bot.`n"

# Loop until the callback listener runspace completes
while ((-not $bot.CallbackJob.AsyncResult.IsCompleted -and $bot.CallbackJob.Runner.InvocationStateInfo.State -eq 'Running') -and (-not $async.IsCompleted -and $powerShell.InvocationStateInfo.State -eq 'Running')) {
    try {
        Start-Sleep -Seconds 3
    }
    catch {
        # Catch any unexpected errors, log a warning, and wait before retry
        Write-Log -Level Error -Message "(Start-HttpStaticListenerBot) $($_)" -UseColor
        Start-Sleep -Seconds 3
    }
}

# Teardown the HTTP listener to stop accepting requests and release resources
try {
    # Abort immediately cancels any in-flight requests and stops the listener
    $listener.Abort()

    # Dispose cleans up underlying network handles and frees memory
    $listener.Dispose()
}
catch {
    # Ignore any errors that occur during abort/dispose
}
finally {
    # Exit the script with a success code to signal normal shutdown
    exit 0
}
