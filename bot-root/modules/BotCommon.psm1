# Import the bot logger utility modules
Import-Module './BotLogger.psm1' -Force

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
        # Expand each adapter’s unicast addresses
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
# skip specified names, and set them as environment variables in the current session.
$importEnvironment = {
    param(
        $EnvironmentFilePath,            # Path to the UTF-8–encoded environment file
        $SkipNames,                      # Array of variable names to exclude from import
        $AdditionalEnvironmentVariables  # Array of extra "KEY=VALUE" strings to append
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
        
        # Set the environment variable in this session
        Set-Item -Path "Env:$key" -Value $value

        # Log via Debug stream for visibility during -Debug preference
        Write-Debug "Set environment variable '$key' to '$value'"
    }
}

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

function New-BotConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$BotName,
        [Parameter(Mandatory = $true)] [string]$BotType,
        [Parameter(Mandatory = $true)] [string]$BotVolume,
        [Parameter(Mandatory = $false)][int]   $CallbackPort,
        [Parameter(Mandatory = $false)][string]$DriverBinaries,
        [Parameter(Mandatory = $false)][int]   $EntryPointPort,
        [Parameter(Mandatory = $true)] [string]$EnvironmentFilePath,
        [Parameter(Mandatory = $true)] [string]$HubUri,
        [Parameter(Mandatory = $false)][int]   $RegistrationTimeout,
        [Parameter(Mandatory = $false)][string]$Token,
        [Parameter(Mandatory = $false)][int]   $WatchDogPollingInterval
    )

    & $importEnvironment -EnvironmentFilePath $EnvironmentFilePath -SkipNames @() -AdditionalEnvironmentVariables @()

    $botId = "$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
    $ipv4  = & $getRemoteIpv4

    if(-not $EntryPointPort) {
        $EntryPointPort = & $getFreePort
    }

    if(-not $CallbackPort -or $CallbackPort -le 0) {
        $CallbackPort = & $getFreePort
    }

    if(-not $RegistrationTimeout){
        $value = 0

        $isNumber = [int]::TryParse($env:G4_REGISTRATION_TIMEOUT, [ref]$value)

        if($isNumber) { $RegistrationTimeout = $value } else { $RegistrationTimeout = 60 }
    }

    if(-not $WatchDogPollingInterval){
        $value = 0

        $isNumber = [int]::TryParse($env:G4_WATCHDOG_INTERVAL, [ref]$value)

        if($isNumber) { $WatchDogPollingInterval = $value } else { $WatchDogPollingInterval = 60 }
    }

    $Token = if (-not $Token) { $env:G4_LICENSE_TOKEN } else { $Token }
    $DriverBinaries = if(-not $DriverBinaries) { $env:DRIVER_BINARIES } else { $DriverBinaries }


    return @{
        Metadata = [PSCustomObject]@{
            BotId   = $botId
            BotName = $BotName
            BotType = $BotType
            IPv4    = $ipv4.IPAddressToString
            Token   = $Token
        }
        
        Endpoints = [PSCustomObject]@{
            Base64InvokeUri     = & $joinUri $HubUri '/api/v4/g4/automation/base64/invoke'
            BotCallbackPrefix   = "http://+:$($CallbackPort)/bot/v1/monitor/$($botId)/"
            BotCallbackUri      = "http://$($ipv4):$($CallbackPort)/bot/v1/monitor/$($botId)"
            BotEntryPointPrefix = "http://+:$($EntryPointPort)/bot/v1/$($BotName)/"
            BotEntryPointUri    = "http://$($ipv4):$($EntryPointPort)/bot/v1/$($BotName)"
            CallbackPort        = $CallbackPort
            DriverBinaries      = $DriverBinaries
            HubUri              = $HubUri
        }
        Directories = [PSCustomObject]@{
            BotAutomationDirectory = [System.IO.Path]::Combine($BotVolume, $BotName, 'bot')
            BotAutomationFile      = [System.IO.Path]::Combine($BotVolume, $BotName, 'bot', 'automation.json')
            BotDirectory           = Join-Path $BotVolume $BotName
            BotErrorsDirectory     = [System.IO.Path]::Combine($BotVolume, $BotName, "errors")
            BotOutputDirectory     = [System.IO.Path]::Combine($BotVolume, $BotName, "output")
            BotVolume              = $BotVolume
        }

        Timeouts = [PSCustomObject]@{
            RegistrationTimeout     = $RegistrationTimeout
            WatchDogPollingInterval = $WatchDogPollingInterval
        }
    }
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
    # and return it as the function’s output.
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
    Path to the UTF-8–encoded environment file to load. Defaults to ".env" in the same directory as this script.

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
    Joins a base URI and a path segment, ensuring exactly one slash between them.

.DESCRIPTION
    The Join-Uri function concatenates two string parts—a base URI and a relative path—
    trimming any trailing slash from the base and any leading slash from the path,
    then inserting a single slash between. This prevents double-slashes or missing
    separators in constructed URIs.

.PARAMETER Base
    The base URI or URL prefix (e.g., "https://example.com/api").

.PARAMETER Path
    The relative segment or resource path to append (e.g., "/v1/items").

.EXAMPLE
    PS> Join-Uri -Base "https://hub.example.com/" -Path "/api/v4/ping"
    https://hub.example.com/api/v4/ping

.NOTES
    - Both inputs are mandatory and must not be null or empty.
    - Does not validate that the resulting URI is well-formed; use [uri] casting if needed.
#>
function Join-Uri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Base,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    # Invoke the previously defined $joinUri script-block with $Base and $Path,
    # then return its result as this function's output.
    return & $joinUri $Base $Path
}

<#
.SYNOPSIS
    Sends a base64-encoded automation payload to the bot automation endpoint, capturing even HTTP 4xx/5xx responses.

.DESCRIPTION
    Constructs the full “invoke” URI by joining the hub base URI with the automation path,
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
        [Parameter(Mandatory)][string] $HubUri,         # Base URI of the hub service
        [Parameter(Mandatory)][string] $Base64Request   # Base64-encoded automation payload to POST
    )

    # Normalize the base URI and append the automation invoke path
    $uri = & $joinUri -Base $HubUri -Path "/api/v4/g4/automation/base64/invoke"

    # Format an exception into a standardized error response object (HTTP 500 fallback).
    $formatError500 = {
        param(
            $Exception  # The caught exception object from a failed request
        )

        # Emit a warning indicating an unexpected error occurred, including the exception message
        Write-Log -Level Warning -Message "(Send-BotAutomationRequest) Unexpected error sending request to '$uri': $($Exception.Message)" -UseColor

        # Build a hashtable containing the error message and full stack trace
        $errorInfo = @{
            message = $Exception.Message      # Exception message text
            stack   = $Exception.StackTrace   # Full stack trace for debugging
        }

        # Return a PSCustomObject with serialized JSON, status code, and raw error info
        return [PSCustomObject]@{
            JsonValue  = $errorInfo | ConvertTo-Json -Depth 5 -Compress 
            StatusCode = 500
            Value      = $errorInfo 
        }
    }

    try {
        # Send the Base64 payload as text/plain, treating HTTP >= 400 as terminating
        $response = Invoke-WebRequest `
            -Uri         $uri `
            -Method      Post `
            -Body        $Base64Request `
            -ContentType "text/plain" `
            -ErrorAction Stop

        # Extract status code and response body
        $statusCode = $response.StatusCode
        $content    = $response.Content

        # Attempt to parse JSON; if parsing fails, leave $parsed as $null
        $parsed = $null
        try {
            $parsed = $content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            # non-JSON response, ignore parse error
        }

        # Return the response object, choosing parsed if available, else raw content
        return [PSCustomObject]@{
            JsonValue  = $content
            StatusCode = $statusCode
            Value      = $(if ($parsed -ne $null) { $parsed } else { $content })
        }
    }
    catch [System.Net.WebException] {
        # Handle HTTP errors (4xx/5xx) thrown as WebException
        $webResponse = $_.Exception.Response  # Extract the underlying HTTP response, if any

        # If no HTTP response available—use generic 500 formatter
        if ($null -eq $webResponse) {
            return & $formatError500 -Exception $_.Exception
        }

        # Convert the StatusCode enum to an integer (e.g. 404, 500)
        $statusCode = [int]$webResponse.StatusCode

        # Read the entire response body as a string
        $content = [System.IO.StreamReader]::new($webResponse.GetResponseStream()).ReadToEnd()

        # Attempt to parse the body as JSON; if it fails, leave $parsed as $null
        $parsed = $null
        try {
            $parsed = $content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            # Non-JSON response—ignore parse errors
        }

        # Return a PSCustomObject with raw JSON, status code, and either the parsed object or raw text
        return [PSCustomObject]@{
            JsonValue  = $content
            StatusCode = $statusCode
            Value      = if ($parsed -ne $null) { $parsed } else { $content }
        }
    }
    catch {
        # Catch-all for any other exception types—format as a generic 500 error
        return & $formatError500 -Exception $_.Exception
    }
}

<#
.SYNOPSIS
    Checks whether a specified bot file exists.

.DESCRIPTION
    Test-BotFile accepts a path to a file and returns $true if that file exists.
    If the file is missing, it writes a warning and returns $false.

.PARAMETER BotFilePath
    The full path to the file to verify (e.g. “C:\bots\mybot\automation.json”).

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

Export-ModuleMember -Function Get-FreePort
Export-ModuleMember -Function Get-RemoteIPv4
Export-ModuleMember -Function Import-EnvironmentVariablesFile
Export-ModuleMember -Function Join-Uri
Export-ModuleMember -Function New-BotConfiguration
Export-ModuleMember -Function Send-BotAutomationRequest
Export-ModuleMember -Function Test-BotFile
Export-ModuleMember -Function Wait-Interval