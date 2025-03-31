<#
.SYNOPSIS
Starts an HTTP listener bot for processing incoming requests.

.DESCRIPTION
This script sets up an HTTP listener to handle incoming requests for a bot. It supports
query string parameters, processes them, and invokes the G4Bot automation process. The bot
can also be run inside a Docker container if the `-Docker` switch is specified.

.PARAMETER BotVolume
The volume or base path where the bot directories are located.

.PARAMETER BotName
The name of the bot, used to construct file paths and log filenames.

.PARAMETER HostPort
The port on which the HTTP listener will run.

.PARAMETER ContentType
The MIME type for the HTTP response (e.g., "application/json").

.PARAMETER DriverBinaries
The driver binaries information to update in the configuration.

.PARAMETER HubUri
The base URI of the hub to which the automation configuration is sent.

.PARAMETER ResponseContent
The default response content to return to the client.

.PARAMETER Token
The authentication token used for updating the configuration.

.PARAMETER Docker
A switch to indicate whether the bot should be run inside a Docker container.

.EXAMPLE
Start-HttpQsListenerBot.ps1 -BotVolume "C:\Bots" -BotName "MyBot" -HostPort 8080 `
    -ContentType "application/json" -DriverBinaries "http://host.docker.internal:4444/wd/hub" `
    -HubUri "http://host.docker.internal:9944" -ResponseContent "{}" -Token "my-token"

Starts the bot listener on port 8080 with the specified parameters.

.EXAMPLE
Start-HttpQsListenerBot.ps1 -BotVolume "C:\Bots" -BotName "MyBot" -HostPort 8080 `
    -ContentType "application/json" -DriverBinaries "http://host.docker.internal:4444/wd/hub" `
    -HubUri "http://host.docker.internal:9944" -ResponseContent "{}" -Token "my-token" -Docker

Runs the bot inside a Docker container with the specified parameters.
#>
param (
    [CmdletBinding()]
    [Parameter(Mandatory = $true)] [string]$BotVolume,
    [Parameter(Mandatory = $true)] [string]$BotName,
    [Parameter(Mandatory = $false)][int]   $HostPort = 8080,
    [Parameter(Mandatory = $false)][string]$ContentType = "application/json; charset=utf-8",
    [Parameter(Mandatory = $true)] [string]$DriverBinaries,
    [Parameter(Mandatory = $true)] [string]$HubUri,
    [Parameter(Mandatory = $false)][string]$ResponseContent = '{\"message\": \"success\"}',
    [Parameter(Mandatory = $true)] [string]$Token,
    [Parameter(Mandatory = $false)][switch]$Docker
)

function Format-Parameters {
    <#
    .SYNOPSIS
    Reads JSON content from a web request, validates it, and returns it along with an HTTP-like status code.

    .DESCRIPTION
    This function reads the JSON content from the InputStream of a provided web request object using its 
    specified ContentEncoding. It logs verbose messages for each processing step. The function then attempts 
    to convert the JSON. If conversion fails (indicating an invalid JSON structure), it returns a status code 
    400 with a JSON error message including error details. If the JSON is valid but not an array 
    (i.e. does not start with '[' and end with ']'), it wraps the JSON content inside array brackets. 
    When no issues are found, the function returns a 200 status code and the (possibly modified) JSON string. 
    Any unexpected exceptions result in a 500 status code with a JSON error message including error details.

    .PARAMETER Request
    The web request object that contains an InputStream and a ContentEncoding property, from which JSON data is read.

    .OUTPUTS
    A hashtable with the following keys:
      - StatusCode: An HTTP-like status code (200, 400, or 500) indicating the outcome.
      - JsonData: The validated (and possibly modified) JSON string, or a JSON error message including error details.
    #>
    param(
        $Request
    )

    try {
        Write-Verbose "Attempting to read JSON content from the request body using the provided encoding."
        $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
        $json   = $reader.ReadToEnd()
        Write-Verbose "Successfully read JSON content from the request body:"
        Write-Verbose $json

        # Attempt to convert the JSON to check its validity.
        try {
            $jsonObject = $json | ConvertFrom-Json
        }
        catch {
            Write-Error "JSON conversion failed: $_.. Returning StatusCode 400 with empty JSON object."
            return @{
                StatusCode = 400
                JsonData   = @{ error = "Invalid JSON"; message = $_.Exception.Message } | ConvertTo-Json -Compress
            }
        }

        # Check if the converted JSON has no properties (if it's a non-array object).
        if (!(Test-Json -JsonString $json)) {
            Write-Verbose "JSON object contains no properties. Returning StatusCode 400."
            return @{
                StatusCode = 400
                JsonData   = @{ error = "Invalid JSON"; message = "The JSON object must contain at least one property and cannot consist solely of primitive values (e.g., strings, numbers, etc.)." } | ConvertTo-Json -Compress
            }
        }

        # Check if the JSON string is wrapped as an array.
        $trimmedJson = $json.Trim()
        if (-not ($trimmedJson.StartsWith("[") -and $trimmedJson.EndsWith("]"))) {
            Write-Verbose "JSON data is not an array. Wrapping in array brackets."
            $json = "[$json]"
        }

        Write-Verbose "JSON validated successfully. Returning StatusCode 200."
        return @{ StatusCode = 200; JsonData = $json }
    }
    catch {
        Write-Error "An unexpected error occurred: $_. Returning StatusCode 500 with empty JSON object."
        return @{
            StatusCode = 500
            JsonData  = @{ error = "Internal Server Error"; message = $_.Exception.Message } | ConvertTo-Json -Compress
        }
    }
}

function Invoke-G4Bot {
    <#
    .SYNOPSIS
    Invokes the G4Bot automation process by updating configuration and sending it to a remote endpoint.

    .DESCRIPTION
    This function reads an existing automation JSON file, updates its configuration with the provided
    parameters, encodes the updated configuration as a Base64 string, and sends it via an HTTP POST
    request to a remote endpoint. It also logs the response and any errors to designated files.

    .PARAMETER BotVolume
    The volume or base path where the bot directories are located.

    .PARAMETER BotName
    The name of the bot, used to construct file paths and log filenames.

    .PARAMETER DriverBinaries
    The driver binaries information to update in the configuration.

    .PARAMETER HubUri
    The base URI of the hub to which the automation configuration is sent.

    .PARAMETER JsonData
    The JSON data content to be injected into the automation configuration.

    .PARAMETER Token
    The authentication token used for updating the configuration.

    .OUTPUTS
    The response returned from the remote endpoint.
    #>
    param(
        $BotVolume,
        $BotName,
        $DriverBinaries,
        $HubUri,
        $JsonData,
        $Token
    )

    Write-Verbose "Generating a unique session identifier using the current date and time."
    $session = (Get-Date).ToString("yyyyMMddHHmmssfff")

    Write-Verbose "Constructing file paths for archive, input, output, and bot directories."
    $archiveDirectory       = [System.IO.Path]::Combine($BotVolume, $BotName, "archive")
    $outputDirectory        = [System.IO.Path]::Combine($BotVolume, $BotName, "output")
    $botDirectory           = Join-Path $BotVolume $BotName
    $botAutomationDirectory = Join-Path $botDirectory "bot"
    $botFilePath            = Join-Path $botAutomationDirectory "automation.json"
    
    Write-Verbose "Constructing output and error log file paths."
    $outputFilePath = [System.IO.Path]::Combine($outputDirectory, "$($BotName)-$($session).json")
    $errorsPath     = [System.IO.Path]::Combine($BotVolume, $BotName, "errors", "$($BotName)-$($session).json")
    
    Write-Verbose "Reading and parsing the 'automation.json' configuration file."
    $botFileContent = [System.IO.File]::ReadAllText($botFilePath, [System.Text.Encoding]::UTF8)
    $botFileJson    = ConvertFrom-Json $botFileContent
    
    # TODO: write datasource to archive folder
    Write-Verbose "Updating the 'dataSource' property in the configuration with the provided JSON data."
    $dataSourceValue = @{
        type   = "JSON"
        source = $JsonData
    }
    if (-not $botFileJson.PSObject.Properties['dataSource']) {
        Add-Member -InputObject $botFileJson -MemberType NoteProperty -Name "dataSource" -Value $dataSourceValue
    }
    else {
        $botFileJson.dataSource = $dataSourceValue
    }

    Write-Verbose "Archiving the data source JSON to the archive directory with a timestamped filename."
    $session = (Get-Date).ToString("yyyyMMddHHmmssfff")
    $dataSourceJson = $JsonData
    [System.IO.File]::WriteAllText([System.IO.Path]::Combine($archiveDirectory, "data-$($session).json"), $dataSourceJson, [System.Text.Encoding]::UTF8)
    
    Write-Verbose "Updating driver binaries and authentication token in the configuration."
    $botFileJson.driverParameters.driverBinaries = $DriverBinaries
    $botFileJson.authentication.token            = $Token
    
    Write-Verbose "Serializing the updated configuration to JSON and encoding it in Base64."
    $botFileContent = ConvertTo-Json $botFileJson -Depth 50 -Compress
    $botBytes       = [System.Text.Encoding]::UTF8.GetBytes($botFileContent)
    $botContent     = [System.Convert]::ToBase64String($botBytes)

    Write-Verbose "Constructing the request URI by appending the API endpoint to the Hub URI."
    $requestUri = "$($HubUri.TrimEnd('/'))/api/v4/g4/automation/base64/invoke"
    
    try {
        Write-Verbose "Sending the Base64-encoded configuration to the remote endpoint at: $requestUri"
        $response = Invoke-RestMethod -Uri $requestUri -Method Post -Body $botContent -ContentType "text/plain"
    }
    catch {
        Write-Verbose "An error occurred while sending the request. Logging error to: $errorsPath. Details: $_"
        "Error: $_" | Out-File -FilePath $errorsPath -Force -ErrorAction Continue
    }
    finally {      
        try {
            Write-Verbose "Saving the response from the remote endpoint to the output file: $outputFilePath"
            $response | ConvertTo-Json -Depth 50 -Compress | Out-File -FilePath $outputFilePath -Force
            Write-Verbose "Response saved successfully."
        }
        catch {
            Write-Verbose "Failed to save the response to: $outputFilePath. Details: $_"
        }
    }

    Write-Verbose "Invoke-G4Bot execution completed."
    return $response
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

function Test-Json {
    <#
    .SYNOPSIS
    Determines if a JSON string is valid and not empty.

    .DESCRIPTION
    This function takes a JSON string as input and attempts to convert it using ConvertFrom-Json.
    It then evaluates "emptiness" as follows:
      - For a JSON object, it is considered empty if it has no properties.
      - For a JSON array, it is considered empty if the array has no elements or if every element in the array 
        is an empty object (i.e. an object with no properties).
    Note: Due to PowerShell 5 behavior, a JSON array containing a single element may be converted as a PSCustomObject 
    instead of an array. This function detects if the original JSON string was wrapped in array brackets and, if so, 
    forces the conversion result into an array.
    
    The function returns **$true** if the JSON is valid and contains data; it returns **$false** if the JSON is empty 
    or invalid.

    .PARAMETER JsonString
    The JSON string to test.

    .OUTPUTS
    A boolean value:
      - **$true** if the JSON is valid and not empty.
      - **$false** if the JSON is empty or invalid.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonString
    )

    # Trim the input and detect if it is meant to be an array.
    $trimmedJson = $JsonString.Trim()
    $originalIsArray = $trimmedJson.StartsWith("[") -and $trimmedJson.EndsWith("]")

    try {
        $parsed = $JsonString | ConvertFrom-Json
    }
    catch {
        Write-Error "Invalid JSON input. Error: $($_.Exception.Message)"
        return $false
    }

    # Workaround for PS 5 behavior: if the original JSON was an array but conversion returns a PSCustomObject,
    # force it into an array.
    if ($originalIsArray -and ($parsed -isnot [array])) {
        $parsed = ,$parsed
    }

    # If the parsed JSON is an array, evaluate its elements.
    if ($parsed -is [array]) {
        if (($null -eq $parsed.Count) -or ($parsed.Count -eq 0)) {
            return $false
        }
        # Check if at least one element is non-empty.
        foreach ($item in $parsed) {
            if ($item -is [PSCustomObject]) {
                if (($null -eq $item.PSObject.Properties.Count) -or ($item.PSObject.Properties.Count -eq 0)) {
                    return $false
                }
            }
            else {
                # Non-object elements (e.g. primitives) are not considered as data.
                return $false
            }
        }
        # If we looped through all elements and found no non-empty ones, return true.
        return $true
    }
    # If the parsed JSON is an object, check its properties.
    elseif ($parsed -is [PSCustomObject]) {
        if (($null -eq $parsed.PSObject.Properties.Count) -or ($parsed.PSObject.Properties.Count -eq 0)) {
            return $false
        }
        else {
            return $true
        }
    }
    else {
        # For primitives and other types, consider them as valid data.
        return $true
    }
}

function Write-Response {
    <#
    .SYNOPSIS
    Writes an HTTP response to the output stream.

    .DESCRIPTION
    This function encodes a given response string into a UTF-8 byte array, sets the HTTP response's
    content type, length, and status code, writes the encoded content to the response's output stream,
    and then closes the stream. All exceptions are caught, and their details are written as verbose output.

    .PARAMETER ContentType
    Specifies the MIME type for the response (e.g., "text/html").

    .PARAMETER Response
    An HttpListenerResponse object to which the response will be written.

    .PARAMETER ResponseContent
    The text content that will be sent as the HTTP response body.

    .PARAMETER StatusCode
    (Optional) The HTTP status code to be set on the response. Defaults to 200.

    .OUTPUTS
    None. The function writes directly to the provided HTTP response output stream.
    #>
    param(
        $ContentType,
        $Response,
        $ResponseContent,
        $StatusCode = 200
    )

    Write-Verbose "Starting Write-Response function."

    try {
        Write-Verbose "Encoding the response string to a UTF8 byte array."
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($ResponseContent)
        $Response.ContentType = $ContentType
        $Response.StatusCode = $StatusCode

        Write-Verbose "Writing the encoded response to the output stream and closing it."
        $output = $Response.OutputStream
        $output.Write($buffer, 0, $buffer.Length)
        $output.Close()
    }
    catch {
        Write-Verbose "An exception occurred during Write-Response execution."
        Write-Verbose "Exception details: $($_.Exception.Message)"
    }
}

Write-Verbose "Construct the base endpoint for the bot."
$botRoute    = "/bot/v1"
$botEndpoint = "http://+:$($HostPort)$($botRoute)/$BotName"

# If the Docker switch is specified, launch a Docker container with the given parameters and exit.
if ($Docker) {
    try {
        Write-Verbose "Docker switch is enabled. Preparing to launch Docker container for bot '$BotName'."
        Write-Verbose "Launching Docker container with: Port mapping '$($HostPort):8080', Volume mapping '$($BotVolume):/bots', and environment variables for BOT_NAME, BOT_URI, CONTENT_TYPE, DRIVER_BINARIES, HUB_URI, RESPONSE_CONTENT, and TOKEN."
        docker run -d -p "$($HostPort):8080" -v "$($BotVolume):/bots" `
            -e BOT_NAME="$($BotName)" `
            -e BOT_PORT="$($HostPort)" `
            -e CONTENT_TYPE="$($ContentType)" `
            -e DRIVER_BINARIES="$($DriverBinaries)" `
            -e HUB_URI="$($HubUri)" `
            -e RESPONSE_CONTENT="$($ResponseContent)" `
            -e TOKEN="$($Token)" `
            --name "$($BotName)-$([guid]::NewGuid())" g4-http-post-listener-bot:latest

        Write-Host "Docker container '$($BotName)' started successfully."
        Exit 0
    }
    catch {
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

Write-Verbose "Creating HttpListener object."
$listener = New-Object System.Net.HttpListener

Write-Verbose "Adding listening prefix '$botEndpoint/' to the HttpListener."
$listener.Prefixes.Add("$botEndpoint/")

Write-Verbose "Adding listening prefix '$botEndpoint/ping/' to the HttpListener."
$listener.Prefixes.Add("$botEndpoint/ping/")

try {
    $listener.Start()
    Write-Host "Listening on $botEndpoint/"
    Write-Host "Server is running.$([System.Environment]::NewLine)Press CTRL+C to stop the server.$([System.Environment]::NewLine)Note: The server will stop after receiving the next HTTP request."

    while ($true) {
        try {
            Write-Verbose "Waiting for incoming HTTP request..."
            $context  = $listener.GetContext()
            $request  = $context.Request
            $response = $context.Response

            Write-Verbose "Handle OPTIONS preflight requests for CORS"
            if ($request.HttpMethod.ToUpper() -eq "OPTIONS") {
                Write-Verbose "OPTIONS request detected. Sending CORS preflight response."
                $response.StatusCode = 200
                $response.Headers.Add("Access-Control-Allow-Origin", "*")
                $response.Headers.Add("Access-Control-Allow-Methods", "POST, OPTIONS")
                $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
                $response.Close()

                continue
            }

            Write-Verbose "Processing a new HTTP request."
            if($request.RawUrl.TrimEnd('/').ToLower().EndsWith("ping") -and $request.HttpMethod.ToUpper() -eq "GET") {
                Write-Verbose "Ping request detected. Sending pong response."
                Write-Response `
                    -ContentType     "application/json; charset=utf-8" `
                    -Response        $response `
                    -ResponseContent '{"message": "pong"}'

                continue
            }

            Write-Verbose "Received HTTP method '$($request.HttpMethod)'. Only POST requests are allowed."
            if ($request.HttpMethod.ToUpper() -ne "POST") {
                Write-Response `
                    -ContentType     "application/json; charset=utf-8" `
                    -Response        $response `
                    -ResponseContent (@{ error = "Method Not Allowed"; message = "Only POST requests are accepted" } | ConvertTo-Json -Compress) `
                    -StatusCode      405

                continue
            }

            # Check for entity body and correct content type (must be application/json)
            if (-not $request.HasEntityBody -or $request.ContentType -notmatch "application/json") {
                Write-Verbose "Request is missing a body or the Content-Type is not 'application/json'."
                Write-Response `
                    -ContentType     "application/json; charset=utf-8" `
                    -Response        $response `
                    -ResponseContent (@{ error = "Invalid request"; message = "JSON content is required." } | ConvertTo-Json -Compress) `
                    -StatusCode      400

                continue
            }
            
            Write-Verbose "..."
            $jsonData = Format-Parameters -Request $request

            if($jsonData.StatusCode -gt 200) {
                Write-Verbose "..."
                Write-Response `
                    -ContentType     "application/json; charset=utf-8" `
                    -Response        $response `
                    -ResponseContent $jsonData.JsonData `
                    -StatusCode      $jsonData.StatusCode

                continue
            }

            Write-Verbose "Invoking G4Bot with updated configuration."
            Invoke-G4Bot `
                -BotVolume      $BotVolume `
                -BotName        $BotName `
                -DriverBinaries $DriverBinaries `
                -HubUri         $HubUri `
                -JsonData       $jsonData.JsonData `
                -Token          $Token

            Write-Verbose "Checking if ResponseContent is empty. Defaulting to an empty JSON object if necessary."
            if ([string]::IsNullOrEmpty($ResponseContent)) {
                Write-Verbose "ResponseContent is empty. Setting default value to '{}'."
                $ResponseContent = "{}"
            }

            Write-Verbose "Sending response back to the client."
            Write-Response `
                -ContentType     $ContentType `
                -Response        $response `
                -ResponseContent $ResponseContent
        }
        catch {
            # Continue on exception to the next iteration of the loop
            Write-Warning "Exception in loop:" $_.Exception.Message
            Write-Response `
                -ContentType     $ContentType `
                -Response        $response `
                -ResponseContent (@{ error = "InternalServerError"; message = $_.Exception.Message } | ConvertTo-Json -Compress) `
                -StatusCode      500
            continue
        }
    }
}
catch [System.Net.HttpListenerException] {
    Write-Error "HttpListener exception:" $_.Exception.Message
}
catch {
    Write-Error "Exception:" $_.Exception.Message
}
finally {
    Write-Verbose "Stopping and closing the HttpListener."
    $listener.Stop()
    $listener.Close()
}