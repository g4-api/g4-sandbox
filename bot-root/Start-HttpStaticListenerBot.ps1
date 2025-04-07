<#
.SYNOPSIS
    Starts an HTTP listener bot that processes incoming GET requests and triggers the G4Bot automation process.

.DESCRIPTION
    This script sets up an HTTP listener to handle incoming GET requests for a bot. When a request is received, the
    listener processes it as follows:
      1. For requests ending in "/ping", the script returns a simple "pong" JSON response.
      2. For all other GET requests, any query string parameters are ignored.
      3. The script invokes the G4Bot automation process, which updates an automation configuration file with new driver 
         binaries and an authentication token, encodes the updated configuration in Base64, and sends it via an HTTP POST 
         request to a remote hub endpoint.
      4. The response from the remote endpoint is logged to an output file, and any errors are logged to a separate error file.
  
    Optionally, if the `-Docker` switch is specified, the script will launch the bot inside a Docker container with the 
    provided parameters instead of starting the HTTP listener directly.

.PARAMETER BotVolume
    The base directory where the bot's folders (such as output, errors, and bot configuration) are located.

.PARAMETER BotName
    The name of the bot. This value is used to construct file paths and log filenames.

.PARAMETER HostPort
    The port on which the HTTP listener will run. Default is 8080.

.PARAMETER ContentType
    The MIME type for the HTTP response. Default is "application/json; charset=utf-8".

.PARAMETER DriverBinaries
    The URL or information for the driver binaries to update in the automation configuration.

.PARAMETER HubUri
    The base URI of the hub to which the updated automation configuration will be sent.

.PARAMETER Base64ResponseContent
    The default response content that will be returned to the client if not modified by the automation process.
    Default is '{"message": "success"}'.

.PARAMETER Token
    The authentication token used to update the automation configuration at the remote endpoint.

.PARAMETER Docker
    A switch indicating whether the bot should be run inside a Docker container. If specified, the script launches
    a Docker container with the provided parameters and exits.

.EXAMPLE
    Start-HttpQsListenerBot.ps1 -BotVolume "C:\Bots" -BotName "MyBot" -HostPort 8080 `
        -ContentType "application/json" -DriverBinaries "http://host.docker.internal:4444/wd/hub" `
        -HubUri "http://host.docker.internal:9944" -Base64ResponseContent "{}" -Token "my-token"

    Starts the bot listener on port 8080 with the specified parameters.

.EXAMPLE
    Start-HttpQsListenerBot.ps1 -BotVolume "C:\Bots" -BotName "MyBot" -HostPort 8080 `
        -ContentType "application/json" -DriverBinaries "http://host.docker.internal:4444/wd/hub" `
        -HubUri "http://host.docker.internal:9944" -Base64ResponseContent "{}" -Token "my-token" -Docker

    Runs the bot inside a Docker container using the specified parameters.
#>
param (
    [CmdletBinding()]
    [Parameter(Mandatory = $true)] [string]$BotVolume,
    [Parameter(Mandatory = $true)] [string]$BotName,
    [Parameter(Mandatory = $false)][int]   $HostPort              = 8080,
    [Parameter(Mandatory = $false)][string]$ContentType           = "application/json; charset=utf-8",
    [Parameter(Mandatory = $true)] [string]$DriverBinaries,
    [Parameter(Mandatory = $true)] [string]$HubUri,
    [Parameter(Mandatory = $false)][string]$Base64ResponseContent = "eyJtZXNzYWdlIjoic3VjY2VzcyJ9",
    [Parameter(Mandatory = $true)] [string]$Token,
    [Parameter(Mandatory = $false)][switch]$Docker
)

function Invoke-G4Bot {
    <#
    .SYNOPSIS
        Updates the automation configuration and initiates the G4Bot process via a remote endpoint.

    .DESCRIPTION
        This function performs the following steps to trigger the G4Bot automation process:
          1. Generates a unique session identifier based on the current date and time.
          2. Constructs file paths for output, bot configuration, and error logs.
          3. Reads and parses the existing "automation.json" configuration file.
          4. Updates the configuration with new driver binaries and an authentication token.
          5. Serializes the updated configuration into JSON, encodes it in Base64, and sends it via an HTTP POST request 
             to the remote hub endpoint.
          6. Logs the response or any errors to designated output and error log files.
    
    .PARAMETER BotVolume
        The base directory where the bot's folders (e.g., output, errors) are located.

    .PARAMETER BotName
        The name of the bot; used to construct file paths and log filenames.

    .PARAMETER DriverBinaries
        The driver binaries configuration to update in the automation file.

    .PARAMETER HubUri
        The base URI of the hub to which the updated automation configuration is sent.

    .PARAMETER Token
        The authentication token required to update the configuration at the remote endpoint.

    .OUTPUTS
        Returns the response received from the remote endpoint after sending the updated configuration.
    #>
    param(
        $BotVolume,
        $BotName,
        $DriverBinaries,
        $HubUri,
        $Token
    )

    Write-Verbose "Generating a unique session identifier using the current date and time"
    $session = (Get-Date).ToString("yyyyMMddHHmmssfff")

    Write-Verbose "Constructing file paths for, input, output, and bot directories"
    $outputDirectory        = [System.IO.Path]::Combine($BotVolume, $BotName, "output")
    $botDirectory           = Join-Path $BotVolume $BotName
    $botAutomationDirectory = Join-Path $botDirectory "bot"
    $botFilePath            = Join-Path $botAutomationDirectory "automation.json"
    
    Write-Verbose "Constructing output and error log file paths"
    $outputFilePath = [System.IO.Path]::Combine($outputDirectory, "$($BotName)-$($session).json")
    $errorsPath     = [System.IO.Path]::Combine($BotVolume, $BotName, "errors", "$($BotName)-$($session).json")
    
    Write-Verbose "Reading and parsing the 'automation.json' configuration file"
    $botFileContent = [System.IO.File]::ReadAllText($botFilePath, [System.Text.Encoding]::UTF8)
    $botFileJson    = ConvertFrom-Json $botFileContent
    
    Write-Verbose "Updating driver binaries and authentication token in the configuration"
    $botFileJson.driverParameters.driverBinaries = $DriverBinaries
    $botFileJson.authentication.token            = $Token
    
    Write-Verbose "Serializing the updated configuration to JSON and encoding it in Base64"
    $botFileContent = ConvertTo-Json $botFileJson -Depth 50 -Compress
    $botBytes       = [System.Text.Encoding]::UTF8.GetBytes($botFileContent)
    $botContent     = [System.Convert]::ToBase64String($botBytes)

    Write-Verbose "Constructing the request URI by appending the API endpoint to the Hub URI"
    $requestUri = "$($HubUri.TrimEnd('/'))/api/v4/g4/automation/base64/invoke"
    
    try {
        Write-Host "Sending the Base64-encoded configuration to the remote endpoint at: $($requestUri)"
        $response = Invoke-WebRequest -Uri $requestUri -Method Post -Body $botContent -ContentType "text/plain"
    }
    catch {
        $baseException = $_.Exception.GetBaseException()
        $errorResponse = @{
            error      = "Internal Server Error"
            message    = $baseException.Message
            stackTrace = $baseException.StackTrace
        }
        $errorResponseJson = ($errorResponse | ConvertTo-Json -Depth 30 -Compress)
        $response = @{
            Content       = $errorResponseJson
            Base64Content = ([System.Convert]::ToBase64String(([System.Text.Encoding]::UTF8.GetBytes($errorResponseJson))))
            ContentType   = "application/json; charset=utf-8"
            StatusCode    = 500
        }

        $response.Content | Out-File -FilePath $errorsPath -Force -ErrorAction Continue
        Write-Error "An error occurred '$($baseException.Message)'.$([System.Environment]::NewLine)Check $($errorsPath) for details"
    }
    try {
        Write-Verbose "Saving the response from the remote endpoint to the output file: $($outputFilePath)"
        if ($null -ne $outputFilePath -and $response.StatusCode -lt 204) {
            $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 30 -Compress -ErrorAction Continue | Out-File -FilePath $outputFilePath -Force -ErrorAction Continue
        }
    }
    catch {
        Write-Error "Failed to save response to: $outputFilePath. Error details: $($_.Exception.GetBaseException().Message)"
    }

    Write-Verbose "Invoke-G4Bot execution completed"
    return $response
}

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

function Write-Response {
    <#
    .SYNOPSIS
        Writes an HTTP response to the output stream.

    .DESCRIPTION
        This function encodes a given response string into a UTF-8 byte array, sets the HTTP response's
        content type, length, and status code, writes the encoded content to the response's output stream,
        and then closes the stream.

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
        $Base64ResponseContent,
        $StatusCode = 200
    )

    try {
        Write-Verbose "Encoding the response string to a UTF8 byte array"
        $decodedContent           = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Base64ResponseContent)))
        $buffer                   = [System.Text.Encoding]::UTF8.GetBytes($decodedContent)
        $Response.ContentLength64 = $buffer.Length
        $Response.ContentType     = $ContentType
        $Response.StatusCode      = $StatusCode

        Write-Verbose "Writing the encoded response to the output stream and closing it"
        $output = $Response.OutputStream
        $output.Write($buffer, 0, $buffer.Length)
    }
    catch {
        Write-Error "An error occurred while writing the response: $($_.Exception.GetBaseException().Message)"
    }
    finally {
        Write-Verbose "Ensure that the output stream is closed regardless of any error"
        if ($Response -and $Response.OutputStream) {
            $Response.OutputStream.Close()
        }
    }
}

Write-Verbose "Construct the base endpoint for the bot"
$botRoute    = "/bot/v1"
$botEndpoint = "http://+:$($HostPort)$($botRoute)/$BotName"

# If the Docker switch is specified, launch a Docker container with the given parameters and exit.
if ($Docker) {
    try {
        Write-Verbose "Docker switch is enabled. Preparing to launch Docker container for bot '$($BotName)'."
        Write-Verbose "Launching Docker container with: Port mapping '$($HostPort):8080', Volume mapping '$($BotVolume):/bots'."
        Write-Verbose "Building the Docker command from the specified parameters."
        $cmdLines = @(
            "run -d -p `"$($HostPort):8080`" -v `"$($BotVolume):/bots`"",
            " -e BOT_NAME=`"$($BotName)`"",
            " -e BOT_PORT=`"$($HostPort)`"",
            " -e CONTENT_TYPE=`"$($ContentType)`"",
            " -e DRIVER_BINARIES=`"$($DriverBinaries)`"",
            " -e HUB_URI=`"$($HubUri)`"",
            " -e BASE64_RESPONSE_CONTENT=`"$($Base64ResponseContent)`"",
            " -e TOKEN=`"$($Token)`"",
            " --name `"$($BotName)-$([guid]::NewGuid())`" g4-http-static-listener-bot:latest"
        )

        Write-Verbose "Joining command parts into a single Docker command string."
        $dockerCmd = $cmdLines -join [string]::Empty

        Write-Host "Invoking Docker with the following command:$([System.Environment]::NewLine)docker $($dockerCmd)"
        $process = Start-Process -FilePath "docker" -ArgumentList $dockerCmd -PassThru
        $process.WaitForExit(60000)
        
        Write-Host "Docker container for bot '$($BotName)' launched successfully."
        Exit 0
    }
    catch {
        Write-Error "Failed to start Docker container for bot '$($BotName)': $($_.Exception.GetBaseException())"
        Exit 1
    }
}

try {
    Write-Verbose "Setting Environment Parameters"
    Import-EnvironmentVariablesFile
}
catch {
    Write-Error "Failed to set environment parameters: $($_.Exception.GetBaseException())"
}

Write-Verbose "Constructing the command line for 'Start-HttpStaticListenerBot.ps1' with the user parameters"
$cmdLines = @(
    ".\Start-HttpStaticListenerBot.ps1",
    "-BotVolume `"$($BotVolume)`"",
    "-BotName `"$($BotName)`"",
    "-HostPort $($HostPort)",
    "-ContentType `"$($ContentType)`"",
    "-DriverBinaries `"$($DriverBinaries)`"",
    "-HubUri `"$($HubUri)`"",
    "-Base64ResponseContent `"$($Base64ResponseContent)`"",
    "-Token `"$($Token)`""
) -join " "
Write-Host "Invoking Process with the following command:$([System.Environment]::NewLine)$($cmdLines)"

Write-Verbose "Creating HttpListener object"
$listener = New-Object System.Net.HttpListener

Write-Verbose "Adding listening prefix '$($botEndpoint)/' to the HttpListener"
$listener.Prefixes.Add("$($botEndpoint)/")

Write-Verbose "Adding listening prefix '$($botEndpoint)/ping/' to the HttpListener"
$listener.Prefixes.Add("$($botEndpoint)/ping/")

try {
    $listener.Start()
    Write-Host "Listening on $($botEndpoint)/"
    Write-Host "Server is running.$([System.Environment]::NewLine)Press CTRL+C to stop the server.$([System.Environment]::NewLine)Note: The server will stop after receiving the next HTTP request"

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

            Write-Verbose "Received HTTP method '$($request.HttpMethod)'. Only GET requests are allowed"
            if ($request.HttpMethod.ToUpper() -ne "GET") {
                Write-Response `
                    -ContentType           "application/json; charset=utf-8" `
                    -Response              $response `
                    -Base64ResponseContent "eyJlcnJvciI6Ik1ldGhvZCBOb3QgQWxsb3dlZCIsIm1lc3NhZ2UiOiJPbmx5IEdFVCByZXF1ZXN0cyBhcmUgYWNjZXB0ZWQifQ==" `
                    -StatusCode            405

                continue
            }

            Write-Verbose "Processing a new HTTP request"
            if($request.RawUrl.TrimEnd('/').ToLower().EndsWith("ping")) {
                Write-Verbose "Ping request detected. Sending pong response"
                Write-Response `
                    -ContentType           "application/json; charset=utf-8" `
                    -Response              $response `
                    -Base64ResponseContent "eyJtZXNzYWdlIjoicG9uZyJ9"

                continue
            }

            # If query string parameters are present, notify that they will not be processed.
            if ($request.QueryString.Count -gt 0) {
                Write-Verbose "Detected query string parameters. These parameters will be ignored by the listener"
            }

            Write-Verbose "Invoking G4Bot with updated configuration"
            $botResponse = Invoke-G4Bot `
                -BotVolume      $BotVolume `
                -BotName        $BotName `
                -DriverBinaries $DriverBinaries `
                -HubUri         $HubUri `
                -Token          $Token

            Write-Verbose "Checking if ResponseContent is empty. Defaulting to an empty JSON object if necessary"
            if ([string]::IsNullOrEmpty($Base64ResponseContent)) {
                Write-Verbose "ResponseContent is empty. Setting default value to '{}'"
                $Base64ResponseContent = "e30="
            }

            Write-Verbose "Sending response back to the client"
            if($botResponse.StatusCode -gt 204) {
                Write-Response `
                    -ContentType           $botResponse.ContentType `
                    -Response              $response `
                    -Base64ResponseContent $botResponse.Base64Content `
                    -StatusCode            $botResponse.StatusCode

                continue
            }
            Write-Response `
                -ContentType           $ContentType `
                -Response              $response `
                -Base64ResponseContent $Base64ResponseContent
        }
        catch {
            # Continue on exception to the next iteration of the loop
            $baseException     = $_.Exception.GetBaseException()
            $exceptionResponse = (@{ error = $baseException.StackTrace; message = $baseException.Message } | ConvertTo-Json -Depth 30 -Compress)
            Write-Warning "Exception in loop: $($baseException.Message)"
            Write-Response `
                -ContentType     $ContentType `
                -Response        $response `
                -Base64ResponseContent ([System.Convert]::ToBase64String(([System.Text.Encoding]::UTF8.GetBytes($exceptionResponse)))) `
                -StatusCode      500

            continue
        }
    }
}
catch [System.Net.HttpListenerException] {
    Write-Error "HttpListener exception:" $_.Exception.GetBaseException().Message
}
catch {
    Write-Error "Exception:" $_.Exception.GetBaseException().Message
}
finally {
    Write-Verbose "Stopping and closing the HttpListener"
    $listener.Stop()
    $listener.Close()
}
