# Change to the script's own directory so any relative paths resolve correctly
Set-Location -Path $PSScriptRoot

# Import the bot logger utility modules
Import-Module './BotLogger.psm1'    -Force
Import-Module './BotUtilities.psm1' -Force

# Scriptblock to find an available TCP port on the local loopback interface
$getFreePort = {
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

# Scriptblock to retrieve the first non-loopback, non-link-local IPv4 address of the host
$getRemoteIpv4 = {
    [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
    Where-Object {
        # Only adapters that are Up and not loopback or tunnel (e.g. Docker, VPN)
        $_.OperationalStatus    -eq [System.Net.NetworkInformation.OperationalStatus]::Up -and
        $_.NetworkInterfaceType -ne [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback -and
        $_.NetworkInterfaceType -ne [System.Net.NetworkInformation.NetworkInterfaceType]::Tunnel
    } |
    ForEach-Object {
        # Expand each adapter's unicast addresses
        $_.GetIPProperties().UnicastAddresses
    } |
    Where-Object {
        # Only IPv4 addresses
        $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
    } |
    ForEach-Object {
        # Extract the raw IPAddress object
        $_.Address
    } |
    Where-Object {
        # Exclude loopback and link-local addresses
        $_.ToString() -ne '127.0.0.1' -and $_.ToString() -notmatch '^169\.254\.'
    } |
    Select-Object -First 1
}

# Scriptblock to import key/value pairs from a file (plus any additional entries),
# skip specified names, and set them as environment variables in the current session,
# but only if they aren't already set.
$importEnvironment = {
    param(
        [string]  $EnvironmentFilePath            = (Join-Path $PSScriptRoot ".env"), # Default to ".env" in script folder
        [string[]]$SkipNames                      = @(),                              # Names to omit from import
        [string[]]$AdditionalEnvironmentVariables = @()                               # Extra KEY=VALUE pairs to include
    )

    # Ensure the file exists before proceeding
    if (-Not (Test-Path $EnvironmentFilePath)) {
        Write-Warning "Environment file not found at path: $EnvironmentFilePath"
        return
    }

    # Read all lines from file, then append any additional variables
    $parametersCollection = (Get-Content $EnvironmentFilePath -Force -Encoding UTF8) + $AdditionalEnvironmentVariables
    
    # Process each line to set environment variables
    $parametersCollection | ForEach-Object {
        # Skip comments and blank lines
        if ($_.Trim().StartsWith('#') -or [string]::IsNullOrWhiteSpace($_)) {
            return
        }

        # Split into key/value pair on the first '=' only
        $parts = $_.Split('=', 2)
        
        # If malformed line, ignore
        if ($parts.Length -ne 2) {
            return 
        }
        
        $key   = $parts[0].Trim()   # variable name
        $value = $parts[1].Trim()   # variable value

        # Skip variables in the provided skip list
        if ($SkipNames -contains $key) {
            return
        }

        # If this variable is already set in this session (non-empty), skip it
        $existingValue = [System.Environment]::GetEnvironmentVariable($key)
        if (-not [string]::IsNullOrEmpty($existingValue)) {
            Write-Debug "Environment variable '$($key)' already set to '$($existingValue)', skipping"
            return
        }
        
        # Set the environment variable in this session
        Set-Item -Path "Env:$($key)" -Value $value

        # Log via Debug stream for visibility during -Debug preference
        Write-Debug "Set environment variable '$($key)' to '$($value)'"
    }
}

# Creates a generic structured error object for HTTP-style error responses.
$newGenericError = {
    param(
        $Exception,
        $StatusCode,
        $Title,
        $Detail     = $Exception.Message,
        $Controller = 'InvokeBase64',
        $Action     = 'Automation',
        $TraceId    = $(Get-Date -Format "yyyyMMdd-HHmmss-fffffff")
    )

    # Extract the name of the exception type (e.g., ArgumentNullException)
    $exceptionType = $Exception.GetType().Name

    # Get the full stack trace for debugging purposes
    $stackTrace = $Exception.ToString()

    # Construct a structured error object with all provided metadata
    $errorObject = [PSCustomObject]@{
        title   = $Title                        # Error title
        status  = $StatusCode                   # HTTP status code
        detail  = $Detail                       # Detailed message

        # Errors dictionary, keyed by exception type, with stack trace as array
        errors  = @{
            $exceptionType = @($stackTrace)
        }

        # Route-related metadata (filtered to exclude nulls)
        # Remove null/empty entries
        routeData = @{
            action     = $Action
            controller = $Controller
        }

        # Unique trace ID for tracking
        traceId = $TraceId
    }

    # Return both raw object and serialized JSON (compressed for response)
    return @{
        JsonValue = $errorObject | ConvertTo-Json -Depth 10 -Compress
        Value     = $errorObject
    }
}

# Checks if a specific TCP port is free on the local loopback interface
$testPort = {
    param(
        [int]$PortToTest
    )

    # Retrieve all active TCP listeners on the machine (all interfaces)
    $listeners = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()

    # If any listener's Port equals our target, it's in use
    if ($listeners.Port -contains $PortToTest) {
        return $false
    }

    # Port is free
    return $true
}

function New-BotConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)] [string] $BotId,
        [Parameter(Mandatory = $false)] [string] $BotName,
        [Parameter(Mandatory = $false)] [string] $BotType,
        [Parameter(Mandatory = $false)] [string] $BotVolume,
        [Parameter(Mandatory = $false)] [string] $CallbackIngress,
        [Parameter(Mandatory = $false)] [string] $CallbackUri,
        
        [Parameter(Mandatory = $false)] [string] $DriverBinaries,
        [Parameter(Mandatory = $false)] [string] $EntryPointIngress,
        [Parameter(Mandatory = $false)] [string] $EntryPointUri,

        [Parameter(Mandatory = $true)]  [string] $EnvironmentFilePath,
        [Parameter(Mandatory = $false)] [string] $HubUri,
        [Parameter(Mandatory = $false)] [int]    $RegistrationTimeout,
        [Parameter(Mandatory = $false)] [string] $Token,
        [Parameter(Mandatory = $false)] [int]    $WatchDogPollingInterval
    )

    # Scriptblock to converts a string to an integer, returning a default if parsing fails.
    $convertToNumber = {
        param(
            [string]$Number,       # The input string to convert
            [int]   $DefaultValue  # Value to return when parsing fails
        )

        # Prepare an integer variable to receive the parsed value
        $value = 0

        # Attempt to parse the string into an integer; $isNumber is $true on success
        $isNumber = [int]::TryParse($Number, [ref]$value)

        if ($isNumber) {
            # If parsing succeeded, return the parsed integer
            return $value
        }

        # If parsing failed, return the provided default value
        return $DefaultValue
    }

    # Scriptblock to constructs a bot monitor endpoint URL from a base callback URI and bot identifier.
    $formatCallback = {
        param(
            [Uri]   $CallbackUri,  # The base URI to format (e.g. "https://example.com")
            [string]$BotId         # The unique bot identifier to append to the path
        )

        # Return null if no URI was provided
        if (-not $CallbackUri) {
            return $null
        }

        # Get the URI scheme (http or https)
        $scheme = $CallbackUri.Scheme

        # Get the hostname (without port)
        $botHost = $CallbackUri.Host

        # Determine port: if the original URI's port is non-positive, fetch a free one; otherwise use it
        $port = if (-not $CallbackUri.Port -or $CallbackUri.Port -le 0) {
            & $getFreePort
        }
        else {
            $CallbackUri.Port
        }

        # Test if the CallbackUri's port is available
        $port = if (& $testPort -PortToTest $CallbackUri.Port) {
            # Port is free�use the original CallbackUri port
            $CallbackUri.Port
        }
        else {
            Write-Log -Level Warning -Message "(New-BotConfiguration) Port $($CallbackUri.Port) isn't available right now; Picking a free one for you." -UseColor
            & $getFreePort
        }


        # Build the authority portion:
        # - If port is default HTTP (80) or HTTPS (443), omit port.
        # - Otherwise include host:port.
        $authority = if (-not $port -or ($port -eq 80 -or $port -eq 443)) {
            "$($botHost)"
        }
        else {
            "$($botHost):$port"
        }

        # Combine scheme, authority, and bot path into the final URL
        return "$($scheme)://$($authority)/bot/v1/monitor/$($BotId)"
    }

    # Imports environment settings from the specified file, with optional exclusions and additions.
    & $importEnvironment `
        -EnvironmentFilePath            $EnvironmentFilePath `
        -SkipNames                      @() `
        -AdditionalEnvironmentVariables @()

    # Environment
    $BotName        = if(-not $BotName)        { $env:BOT_NAME }         else { $BotName }
    $BotVolume      = if(-not $BotVolume)      { $env:BOT_VOLUME }       else { $BotVolume }
    $DriverBinaries = if(-not $DriverBinaries) { $env:DRIVER_BINARIES }  else { $DriverBinaries }
    $HubUri         = if(-not $HubUri)         { $env:G4_HUB_URI }       else { $HubUri }
    $Token          = if(-not $Token)          { $env:G4_LICENSE_TOKEN } else { $Token }

    # Evaluate SAVE_RESPONSE as Boolean: accepts true, True, 'true', "True", etc.
    $saveResponse = $env:SAVE_RESPONSE -match "^(?i)[`"']?true[`"']?$"

    # Evaluate SAVE_ERRORS as Boolean: accepts true, True, 'true', "True", etc.
    $saveErrors   = $env:SAVE_ERRORS   -match "^(?i)[`"']?true[`"']?$"


    $BotId                      = if([string]::IsNullOrEmpty($BotId)) { "$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())" } else { $BotId }
    $ipv4                       = & $getRemoteIpv4
    $defaultCallbackUri         = [Uri]::new("http://$($ipv4):9213")
    $defaultEntryPointUri       = [Uri]::new("http://$($ipv4):9123")

    [Uri]$botCallbackUri        = if(-not [string]::IsNullOrEmpty($CallbackUri))     { [Uri]::new($CallbackUri) }     else { $defaultCallbackUri }
    [Uri]$botCallbackIngress    = if(-not [string]::IsNullOrEmpty($CallbackIngress)) { [Uri]::new($CallbackIngress) } else { $defaultCallbackUri }
    $botCallbackUriAbsolute     = & $formatCallback -CallbackUri $botCallbackUri     -BotId $botId
    $botCallbackIngressAbsolute = $botCallbackIngress.AbsoluteUri.TrimEnd('/')

    [Uri]$botEntryPointUri        = if(-not [string]::IsNullOrEmpty($EntryPointUri))     { [Uri]::new($EntryPointUri) }     else { $defaultEntryPointUri }
    [Uri]$botEntryPointIngress    = if(-not [string]::IsNullOrEmpty($EntryPointIngress)) { [Uri]::new($EntryPointIngress) } else { $defaultEntryPointUri }
    $botEntryPointUriAbsolute     = & $formatCallback -EntryPointUri $botEntryPointUri     -BotId $botId
    $botEntryPointIngressAbsolute = $botEntryPointIngress.AbsoluteUri.TrimEnd('/')


    #$botCallbackIngressAbsolute = if(-not [string]::IsNullOrEmpty($CallbackIngress)) { $botCallbackIngressAbsolute } else { $botCallbackUriAbsolute }
    #$botCallbackUriAbsolute     = if(-not [string]::IsNullOrEmpty($CallbackUri)) { $botCallbackUriAbsolute } else { $botCallbackIngressAbsolute }
    
    $callbackPort            = [Uri]::new($botCallbackIngressAbsolute).Port
    $entryPointPort          = [Uri]::new($botEntryPointIngressAbsolute).Port
    $RegistrationTimeout     = & $convertToNumber -Number $env:G4_REGISTRATION_TIMEOUT -DefaultValue 60
    $WatchDogPollingInterval = & $convertToNumber -Number $env:G4_WATCHDOG_INTERVAL    -DefaultValue 60

    $BotType = if(-not $BotType) { 'generic-bot' } else { $BotType }

    # Read and parse the automation JSON file
    $botAutomationFile = [System.IO.Path]::Combine($BotVolume, $BotName, 'bot', 'automation.json')
    $botFileContent = if(Test-Path -Path $botAutomationFile) { [System.IO.File]::ReadAllText($botAutomationFile, [System.Text.Encoding]::UTF8) } else { '{ "driverParameters":{"driverBinaries":""},"authentication":{"token":""}}' }
    $botFileJson    = ConvertFrom-Json $botFileContent
    
    # Inject dynamic values: driver binaries URL and authentication token
    $botFileJson.driverParameters.driverBinaries = $DriverBinaries
    $botFileJson.authentication.token            = $Token
    
    # Serialize back to JSON and encode as Base64
    $botFileContent = ConvertTo-Json $botFileJson -Depth 50 -Compress
    $botBytes       = [System.Text.Encoding]::UTF8.GetBytes($botFileContent)
    $botContent     = [System.Convert]::ToBase64String($botBytes)

    return @{
        Metadata = [PSCustomObject]@{
            BotBase64Content = $botContent
            BotContentObject = $botFileJson
            BotId   = $BotId
            BotName = $BotName
            BotType = $BotType
            IPv4    = $ipv4.IPAddressToString
            Token   = $Token
        }
        
        Endpoints = [PSCustomObject]@{
            Base64InvokeUri     = Join-Uri $HubUri '/api/v4/g4/automation/base64/invoke'
            
            
            BotCallbackIngress  = $botCallbackIngressAbsolute
            BotCallbackPrefix   = "http://+:$($callbackPort)/bot/v1/monitor/$($botId)/"
            BotCallbackUri      = $botCallbackUriAbsolute

            BotEntryPointIngress = $botEntryPointIngressAbsolute
            BotEntryPointPrefix = "http://+:$($entryPointPort)/bot/v1/$($BotName)/"
            BotEntryPointUri    = $botEntryPointUriAbsolute

            CallbackIngressPort = 0
            CallbackPort        = $callbackPort
            
            DriverBinaries        = $DriverBinaries
            EntryPointIngressPort = 0
            EntryPointPort        = $entryPointPort
            HubUri                = $HubUri
        }

        Directories = [PSCustomObject]@{
            BotArchiveDirectory     = [System.IO.Path]::Combine($BotVolume, $BotName, "archive")
            BotAutomationDirectory  = [System.IO.Path]::Combine($BotVolume, $BotName, 'bot')
            BotAutomationFile       = $botAutomationFile
            BotDirectory            = [System.IO.Path]::Combine($BotVolume, $BotName)
            BotErrorsDirectory      = [System.IO.Path]::Combine($BotVolume, $BotName, "errors")
            BotInputDirectory       = [System.IO.Path]::Combine($BotVolume, $BotName, "input")
            BotOutputDirectory      = [System.IO.Path]::Combine($BotVolume, $BotName, "output")
            BotExtractionsDirectory = [System.IO.Path]::Combine($BotVolume, $BotName, "extractions")
            BotVolume               = $BotVolume
        }

        Settings = [PSCustomObject]@{
            SaveErrors   = $saveErrors
            SaveResponse = $saveResponse
        }

        Timeouts = [PSCustomObject]@{
            RegistrationTimeout     = $RegistrationTimeout
            WatchDogPollingInterval = $WatchDogPollingInterval
        }
    }
}

<#
.SYNOPSIS
    Creates a generic structured error object for HTTP-style error responses.

.PARAMETER Exception
    The exception object to extract the stack trace and message from.

.PARAMETER StatusCode
    The HTTP status code to associate with the error (e.g. 400, 403, 500).

.PARAMETER Title
    A short, human-readable title summarizing the error.

.PARAMETER Detail
    A more detailed explanation of the error (optional; defaults to Exception.Message).

.PARAMETER Controller
    The name of the controller involved (if applicable).

.PARAMETER Action
    The action method being executed (if applicable).

.PARAMETER TraceId
    Optional trace ID. If not supplied, it defaults to a timestamp-based ID.
#>
function New-GenericError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]  [Exception] $Exception,
        [Parameter(Mandatory = $true)]  [int]       $StatusCode,
        [Parameter(Mandatory = $true)]  [string]    $Title,
        [Parameter(Mandatory = $false)] [string]    $Detail = $Exception.Message,
        [Parameter(Mandatory = $false)] [string]    $Controller,
        [Parameter(Mandatory = $false)] [string]    $Action,
        [Parameter(Mandatory = $false)] [string]    $TraceId = $(Get-Date -Format "yyyyMMdd-HHmmss-fffffff")
    )

    # Return both raw object and serialized JSON (compressed for response)
    return & $newGenericError `
        -Exception  $Exception `
        -StatusCode $StatusCode `
        -Title      $Title `
        -Detail     $Detail `
        -Controller $Controller `
        -Action     $Action `
        -TraceId    $TraceId
}

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
function Get-FreePort {
    [CmdletBinding()]
    param()

    # Invoke the predefined $getFreePort script-block to retrieve an available TCP port
    return & $getFreePort
}

<#
.SYNOPSIS
    Gets the next file from an input directory, processes it into JSON, and returns a result object.

.DESCRIPTION
    Scans the specified InputDirectory for files matching the given extensions, selects the most recently modified one,
    converts or validates its content into a compact JSON array, and returns a PSCustomObject containing StatusCode,
    Content, and Reason. Finally, moves the processed file to ArchiveDirectory with the Session ID appended to its name.

.PARAMETER InputDirectory
    The path to the folder containing the files to process.

.PARAMETER ArchiveDirectory
    The path to the folder where processed files will be archived.

.PARAMETER Session
    A unique session identifier appended to archived filenames to avoid collisions.

.PARAMETER Extensions
    An array of file extensions (without the leading dot) to include, e.g. 'csv','json'.  
    Default is '*' which means any file extension.

.OUTPUTS
    PSCustomObject with properties:
    - StatusCode (int): 200 on success, 404 if no file found, 500 on error.
    - Content (string|null): The minified JSON content or $null.
    - Reason (string): Description of outcome or error message.

.EXAMPLE
    # Process only CSV and JSON files:
    Get-NextFile -InputDirectory 'C:\in' -ArchiveDirectory 'C:\archive' -Session 'ABC123' -Extensions csv,json

.EXAMPLE
    # Process any file type:
    Get-NextFile -InputDirectory 'C:\in' -ArchiveDirectory 'C:\archive' -Session 'ABC123'
#>
function Get-NextFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDirectory,

        [Parameter(Mandatory = $true)]
        [string]$ArchiveDirectory,

        [Parameter(Mandatory = $true)]
        [string]$Session,

        [Parameter(Mandatory = $false)]
        [string[]]$Extensions = @('*')
    )

    # Initialize variables for result and the reference to the latest file found
    $resultObject = $null
    $latestFile   = $null

    try {
        # Retrieve all files from the input directory
        $items = Get-ChildItem -Path $InputDirectory -File

        # If Extensions is not '*' then filter by those extensions (trim leading dot for comparison)
        if (-not ($Extensions -contains '*')) {
            $files = $items | Where-Object {
                $ext = $_.Extension.TrimStart('.')
                $Extensions -contains $ext
            }
        }
        else {
            $files = $items
        }

        # If no file is found, return a result object with a 404 status
        if (-not $files) {
            if (-not ($Extensions -contains '*')) {
                $extList = $Extensions -join ', '
                $reason  = "No files with extensions [$($extList)] found in input folder: $($InputDirectory)"
            }
            else {
                $reason = "No files found in input folder: $($InputDirectory)"
            }

            return [PSCustomObject]@{
                StatusCode = 404
                Content    = $null
                Reason     = $reason
            }
        }

        # Select the most recently modified file
        $latestFile = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        # Process based on the file extension
        if ($latestFile.Extension -eq ".csv") {
            # Import CSV and convert to a compact JSON string
            $csvData     = Import-Csv -Path $latestFile.FullName -Encoding UTF8
            $jsonContent = $csvData | ConvertTo-Json -Depth 3 -Compress
        }
        elseif ($latestFile.Extension -eq ".json") {
            # Read raw JSON text from the file
            $rawJson = [System.IO.File]::ReadAllText($latestFile.FullName, [System.Text.Encoding]::UTF8)

            # Validate JSON by parsing; throw if invalid
            try {
                $jsonObject = $rawJson | ConvertFrom-Json
            }
            catch {
                throw "File $($latestFile.FullName) is not a valid JSON file."
            }

            # Re-serialize to a compact JSON string
            $jsonContent = $jsonObject | ConvertTo-Json -Depth 10 -Compress
        }
        else {
            throw "Unsupported file type: $($latestFile.Extension)"
        }

        # Ensure the JSON string is an array; wrap if needed
        if ($jsonContent[0] -ne '[' -or $jsonContent[-1] -ne ']') {
            $jsonContent = "[$($jsonContent)]"
        }

        # Build a success result object
        $resultObject = [PSCustomObject]@{
            StatusCode = 200
            Content    = $jsonContent
            File       = $latestFile
            Reason     = "File processed successfully: $($latestFile.Name)"
        }
    }
    catch {
        # On error, return a 500 result with the error message
        $resultObject = [PSCustomObject]@{
            StatusCode = 500
            Content    = $null
            File       = $null
            Reason     = $_.Exception.GetBaseException().Message
        }
    }
    finally {
        # If a file was processed, attempt to archive it
        if ($latestFile -and (Test-Path -Path $latestFile.FullName)) {
            try {
                # Construct a unique archive filename using the session ID
                $baseName        = [System.IO.Path]::GetFileNameWithoutExtension($latestFile.Name)
                $extension       = [System.IO.Path]::GetExtension($latestFile.Name)
                $archiveFileName = "$($baseName)-$($Session)$($extension)"
                $archiveFilePath = Join-Path $ArchiveDirectory $archiveFileName

                # Move the file into the archive directory
                Move-Item -Path $latestFile.FullName -Destination $archiveFilePath -Force
            }
            catch {
                # If archiving fails, append the error to the result's Reason
                $archiveError = "Failed to archive file: $($_.Exception.GetBaseException().Message)"
                $resultObject.Reason += " | $archiveError"
            }
        }
    }

    return $resultObject
}

<#
.SYNOPSIS
    Returns the first non-loopback, non-link-local IPv4 address on the machine.

.DESCRIPTION
    Queries all network adapters that are Up (excluding loopback and tunnel interfaces),
    then finds their assigned IPv4 unicast addresses, filters out 127.0.0.1 and 169.254.x.x,
    and returns the first valid address suitable for remote access.

.OUTPUTS
    System.Net.IPAddress

.EXAMPLE
    PS> Get-RemoteIPv4
    172.24.6.236
#>
function Get-RemoteIPv4 {
    [CmdletBinding()]
    param()

    # Invoke the predefined script-block to get the first non-loopback IPv4 address
    # and return it as the function's output.
    return & $getRemoteIpv4
}

<#
.SYNOPSIS
    Loads environment variables from a file into the current session.

.DESCRIPTION
    Reads key=value pairs from the specified environment file (defaults to ".env" in the script's folder),
    skips any names provided in the SkipNames array, appends any AdditionalEnvironmentVariables entries,
    and sets them as environment variables for this session by delegating to the internal import scriptblock.

.PARAMETER EnvironmentFilePath
    Path to the UTF-8�encoded environment file to load. Defaults to ".env" in the same directory as this script.

.PARAMETER SkipNames
    An array of variable names to exclude from import (case-sensitive).

.PARAMETER AdditionalEnvironmentVariables
    Additional "KEY=VALUE" strings to process after reading the file.

.EXAMPLE
    # Load from the default .env
    Import-EnvironmentVariablesFile

.EXAMPLE
    # Load from a custom file, skip SECRET and add an extra var
    Import-EnvironmentVariablesFile `
        -EnvironmentFilePath "C:\config\prod.env" `
        -SkipNames "SECRET" `
        -AdditionalEnvironmentVariables "API_KEY=abcdef12345"
#>
function Import-EnvironmentVariablesFile {
    [CmdletBinding()]
    param(
        [string]  $EnvironmentFilePath            = (Join-Path $PSScriptRoot ".env"), # Default to ".env" in script folder
        [string[]]$SkipNames                      = @(),                              # Names to omit from import
        [string[]]$AdditionalEnvironmentVariables = @()                               # Extra KEY=VALUE pairs to include
    )

    # Delegate the heavy lifting to the internal scriptblock
    & $importEnvironment `
        -EnvironmentFilePath            $EnvironmentFilePath `
        -SkipNames                      $SkipNames `
        -AdditionalEnvironmentVariables $AdditionalEnvironmentVariables
}

<#
.SYNOPSIS
    Sends a base64-encoded automation payload to the bot automation endpoint, capturing even HTTP 4xx/5xx responses.

.DESCRIPTION
    Constructs the full �invoke� URI by joining the hub base URI with the automation path,
    then posts the Base64Request string as plain text using Invoke-WebRequest.  
    Catches System.Net.WebException to extract the HTTP status code and response body
    when the server returns error codes (e.g. 500), and always returns a PSCustomObject
    with JsonValue, StatusCode, and Value fields.

.PARAMETER HubUri
    The base URI of the hub service (e.g. "https://hub.example.com").

.PARAMETER Base64Request
    The Base64-encoded automation request payload to send.

.EXAMPLE
    # Send a base64 automation request; even if the hub returns HTTP 500, we extract and return its body
    $result = Send-BotAutomationRequest `
        -HubUri "https://hub.example.com" `
        -Base64Request "eyJhc3NldCI6ICJhYmMiIH0="
    if ($result.StatusCode -eq 200) {
        "Success: $($result.Value)"
    }
    else {
        "Error $($result.StatusCode): $($result.Value)"
    }
#>
function Send-BotAutomationRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $HubUri,       # Base URI of the automation hub.
        [Parameter(Mandatory)][string] $Base64Request # Base64-encoded request payload.
    )

    # Suppress progress output.
    $ProgressPreference = 'SilentlyContinue'

    # Formats a detailed error response for HTTP 500 Internal Server Errors.
    $formatError500 = {
        param([Exception]$Exception, [string]$Uri)
        try {

        $baseException = $Exception.GetBaseException()

        # Emit a warning with the exception details.
        Write-Log `
            -Level    Warning `
            -Message  "(Send-BotAutomationRequest) Unexpected error sending request to '$($Uri)': $($baseException.Message)" `
            -UseColor

        # Create error info hashtable.
        $errorInfo = & $newGenericError `
            -Exception  $baseException `
            -StatusCode 500 `
            -Title      'Unexpected Error' `
            -Detail     $baseException.Message `
            -Controller 'Automation' `
            -Action     'InvokeBase64' `
            -TraceId    $(Get-Date -Format "yyyyMMdd-HHmmss-fffffff")

        # Return structured error response.
        return [PSCustomObject]@{
            Base64Content = ([System.Convert]::ToBase64String(([System.Text.Encoding]::UTF8.GetBytes($errorInfo.JsonValue))))
            ContentType   = "application/json; charset=utf-8"
            JsonValue     = $errorInfo.JsonValue
            StatusCode    = @('500')
            Value         = $errorInfo.Value
        }
        }
        catch{
            Write-Log `
                -Level    Warning `
                -Message  "(Send-BotAutomationRequest) Unexpected error: $($_.Exception.GetBaseException().Message)" `
                -UseColor 
        }
    }

    # Constructs the result object from HTTP response.
    $newResult = {
        param($StatusCode, [string]$Content)

        $parsed = $null
        try { $parsed = $Content | ConvertFrom-Json -ErrorAction Stop } catch {}

        # Return structured success/error response.
        return [PSCustomObject]@{
            Base64Content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Content))
            ContentType   = "application/json; charset=utf-8"
            JsonValue     = $Content
            StatusCode    = $StatusCode
            Value         = if ($parsed) { $parsed } else { $Content }
        }
    }

    # Performs HTTP request using PowerShell 5.1 semantics.
    $invokePs5 = {
        param($Uri, $Base64Request)

        # Invoke HTTP request and handle WebException for non-2xx responses.
        try {
            $response = Invoke-WebRequest `
              -Uri         $Uri `
              -Method      Post `
              -Body        $Base64Request `
              -ContentType 'text/plain' `
              -ErrorAction Stop

            # Return successful response.
            return & $newResult -StatusCode @("$($response.StatusCode)") -Content $response.Content
        }
        catch {
            $exception = $_.Exception.GetBaseException()
            $exceptionName = $exception.GetType().Name

            # Handle unexpected exceptions.
            if (-not ($exceptionName -eq 'WebException' -and $exception.Response)) {
                return & $formatError500 -Exception $exception -Uri $Uri
            }

            # Read response content from WebException.
            $webResponse = $exception.Response
            $content     = [IO.StreamReader]::new($webResponse.GetResponseStream()).ReadToEnd()

            # Return error response from caught exception.
            return & $newResult -StatusCode @([int]$webResponse.StatusCode) -Content $content
        }
    }

    # Performs HTTP request using PowerShell 7+ semantics.
    $invokePs7 = {
        param($Uri, $Base64Request)

        # Clear previous error and response variables.
        Remove-Variable networkError -ErrorAction SilentlyContinue
        Remove-Variable response     -ErrorAction SilentlyContinue

        try {
            # Invoke HTTP request without automatic HTTP error throwing.
            Invoke-WebRequest `
              -Uri                      $Uri `
              -Method                   Post `
              -Body                     $Base64Request `
              -ContentType              'text/plain' `
              -ErrorAction              Continue `
              -ErrorVariable            networkError `
              -OutVariable              response `
              -ConnectionTimeoutSeconds 30 `
              -SkipHttpErrorCheck

            # Handle HTTP-level errors caught in ErrorVariable.
            if ($networkError) {
                return & $formatError500 -Exception $networkError[-1].Exception -Uri $Uri
            }

            # Convert HTTP response bytes to string.
            $webResponse  = $response[-1]
            $memoryStream = New-Object System.IO.MemoryStream
            $webResponse.RawContentStream.CopyTo($memoryStream)
            
            $bytes   = $memoryStream.ToArray()
            $content = [System.Text.Encoding]::UTF8.GetString($bytes)

            # Return HTTP response.
            return & $newResult -StatusCode $webResponse.StatusCode -Content $content
        }
        catch {
            # Handle low-level network exceptions (DNS, socket).
            return & $formatError500 -Exception $_.Exception -Uri $Uri
        }
    }

    # Build the complete automation URI.
    $automationUri = Join-Uri -Base $HubUri -Path "/api/v4/g4/automation/base64/invoke"

    # Invoke using appropriate method based on PowerShell version.
    $responseObject = if($PSVersionTable.PSVersion.Major -ge 7) {
        # Use the PowerShell 7+ invocation delegate if running on PS 7 or newer
        & $invokePs7 -Uri $automationUri -Base64Request $Base64Request
    } else {
        # Use the PowerShell 5-compatible invocation delegate otherwise
        & $invokePs5 -Uri $automationUri -Base64Request $Base64Request
    }

    # Return the result from the selected invocation method
    return $responseObject
}

<#
.SYNOPSIS
    Checks whether a specified bot file exists.

.DESCRIPTION
    Test-BotFile accepts a path to a file and returns $true if that file exists.
    If the file is missing, it writes a warning and returns $false.

.PARAMETER BotFilePath
    The full path to the file to verify (e.g. �C:\bots\mybot\automation.json�).

.EXAMPLE
    # Check for a specific file
    Test-BotFile -BotFilePath "C:\bots\mybot\automation.json"
#>
function Test-BotFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $BotFilePath
    )

    # Verify the file exists at the given path
    if (Test-Path -Path $BotFilePath) {
        return $true
    }

    # File not found: warn the user with the supplied path
    Write-Log -Level Warning -Message "(Test-BotFile) Bot file not found: '$BotFilePath'" -UseColor
    
    # Indicate failure
    return $false
}

<#
.SYNOPSIS
    Tests whether a specified TCP port is open or available.

.DESCRIPTION
    The Test-Port function wraps and invokes an underlying port-testing implementation
    (a scriptblock or function stored in $testPort) to determine if the given port
    on the local machine is accepting connections.

.PARAMETER PortToTest
    The TCP port number to test. Must be an integer between 1 and 65535.

.EXAMPLE
    Test-Port -PortToTest 80
    # Tests TCP port 80 on the local machine and returns $true if open, $false otherwise.

.NOTES
    Requires that a scriptblock or function named $testPort exists in the session,
    taking a -PortToTest parameter and returning a Boolean result.
#>
function Test-Port {
    [CmdletBinding()]  # Enables advanced function features (common parameters, pipeline support, etc.)
    param(
        # The TCP port number to test (required, position 0).
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateRange(1, 65535)]
        [int]$PortToTest
    )

    # Invoke the underlying port-test logic and return its Boolean result
    return & $testPort -PortToTest $PortToTest
}

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
function Wait-Interval {
    [CmdletBinding()]
    param(
        [int]   $IntervalTime,
        [string]$Message
    )

    # Calculate the next scheduled time by adding the specified interval to the current date and time.
    $nextTime = (Get-Date).AddSeconds($IntervalTime)

    # Format the calculated time in ISO 8601 format.
    $isoNextTime = $nextTime.ToString("o")

    # Display the custom message along with the formatted next invocation time.
    Write-Log -Level Information -Message "(Wait-Interval) $Message $isoNextTime" -UseColor

    # Pause execution for the specified interval.
    Start-Sleep -Seconds $IntervalTime
}

<#
.SYNOPSIS
    Writes an HTTP response, handling no-content and error-status cases.

.DESCRIPTION
    Decodes a Base64-encoded payload and writes it as the HTTP response body, setting
    Content-Type, Content-Length, and Status Code.  
    - If there is no payload and the status code is <= 204, returns 204 No Content.  
    - If there is no payload and the status code is >= 400, returns the given error code with no body.

.PARAMETER Response
    The System.Net.HttpListenerResponse instance to which the function will write.

.PARAMETER Base64ResponseContent
    The response body encoded as a Base64 string. Optional for no-content or error responses.

.PARAMETER ContentType
    The MIME type for the response (default: 'application/json; charset=utf-8').

.PARAMETER StatusCode
    The HTTP status code to return (default: 200).  
    - <= 204 with no body > 204 No Content  
    - >= 400 with no body > returns provided error status with no body

.EXAMPLE
    # Normal JSON response
    Write-Response `
        -Response $ctx.Response `
        -Base64ResponseContent ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"ok":true}'))) `
        -StatusCode 200

.EXAMPLE
    # No-content response
    Write-Response `
        -Response $ctx.Response `
        -StatusCode 204

.EXAMPLE
    # Error response without body
    Write-Response `
        -Response $ctx.Response `
        -StatusCode 404

.NOTES
    - Always closes the response stream to complete the HTTP exchange.
#>
function Write-Response {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerResponse] $Response,

        [Parameter(Mandatory=$false)]
        [string] $Base64ResponseContent,

        [Parameter(Mandatory=$false)]
        [string] $ContentType = "application/json; charset=utf-8",

        [Parameter(Mandatory=$false)]
        [int] $StatusCode = 200
    )

    try {
        # If no body and status <= 204, return 204 No Content immediately
        if ([string]::IsNullOrEmpty($Base64ResponseContent) -and $StatusCode -le 204) {
            $Response.StatusCode      = 204
            $Response.ContentLength64 = 0
            return
        }

        # If no body and status >= 400, return the error status with no content
        if ([string]::IsNullOrEmpty($Base64ResponseContent) -and $StatusCode -ge 400) {
            $Response.StatusCode      = $StatusCode
            $Response.ContentLength64 = 0
            return
        }

        # Decode the Base64 payload into a UTF-8 string
        $decodedContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64ResponseContent))

        # Convert the UTF-8 string into a byte array for writing
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($decodedContent)

        # Set headers for a normal (non-error) response
        $Response.ContentLength64 = $buffer.Length
        $Response.ContentType     = $ContentType
        $Response.StatusCode      = $StatusCode
    }
    catch {
        # Build a JSON object with error details
        $errorObject = @{
            error   = $_.Exception.GetBaseException().StackTrace
            message = $_.Exception.GetBaseException().Message
        } | ConvertTo-Json -Depth 5 -Compress

        # Encode the error JSON into bytes
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($errorObject)

        # Populate response headers for an internal server error
        $Response.ContentLength64  = $buffer.Length
        $Response.ContentType      = "application/json; charset=utf-8"
        $Response.StatusCode       = 500

        # Log a warning with the error message
        Write-Warning "Error writing response: $($_.Exception.GetBaseException().Message)"
    }
    finally {
        # Write whatever is in $buffer (normal body or error JSON) and close the stream
        if ($Response -and $Response.OutputStream) {
            $Response.OutputStream.Write($buffer, 0, $buffer.Length)
            $Response.OutputStream.Close()
        }
    }
}

Export-ModuleMember -Function Get-FreePort
Export-ModuleMember -Function Get-RemoteIPv4
Export-ModuleMember -Function Get-NextFile
Export-ModuleMember -Function Import-EnvironmentVariablesFile
Export-ModuleMember -Function Join-Uri
Export-ModuleMember -Function New-BotConfiguration
Export-ModuleMember -Function Send-BotAutomationRequest
Export-ModuleMember -Function Test-BotFile
Export-ModuleMember -Function Test-Port
Export-ModuleMember -Function Wait-Interval
Export-ModuleMember -Function Write-Response