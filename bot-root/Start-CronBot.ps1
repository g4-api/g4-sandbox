param (
    [CmdletBinding()]
    [Parameter(Mandatory = $false)] [string] $BotId,
    [Parameter(Mandatory = $true)]  [string] $BotName,
    [Parameter(Mandatory = $true)]  [string] $BotVolume,
    [Parameter(Mandatory = $false)] [string] $CallbackIngress,
    [Parameter(Mandatory = $false)] [string] $CallbackUri,
    [Parameter(Mandatory = $false)] [string] $CronSchedules='* * * * *',
    [Parameter(Mandatory = $true)]  [string] $DriverBinaries,
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

# Build the bot's configuration object (endpoints, metadata, timeouts)
$botConfiguration = New-BotConfiguration `
    -BotId               $BotId `
    -BotName             $BotName `
    -BotType             'cron-bot' `
    -BotVolume           $BotVolume `
    -CallbackIngress     $CallbackIngress `
    -CallbackUri         $CallbackUri `
    -DriverBinaries      $DriverBinaries `
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
            " -e CRON_BOT_SCHEDULES=`"$($CronSchedules)`"",
            " -e DRIVER_BINARIES=`"$($botConfiguration.Endpoints.DriverBinaries)`""
            " -e HUB_URI=`"$($botConfiguration.Endpoints.HubUri)`""
            " -e SAVE_ERRORS=`"$($botConfiguration.Settings.SaveErrors)`""
            " -e SAVE_RESPONSE=`"$($botConfiguration.Settings.SaveResponse)`""
            " -e TOKEN=`"$($botConfiguration.Metadata.Token)`""
        )
        
        # Publish port and assign unique container name
        $cmdLines += " -p $($botConfiguration.Endpoints.CallbackPort):$($botConfiguration.Endpoints.CallbackPort)"

        # Set container name and tag
        $cmdLines += " --name `"$($botConfiguration.Metadata.BotName)-$([guid]::NewGuid())`" g4-cron-bot:latest"

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
        Exit 0
    }
}

# Configure PowerShell to display informational messages (Write-Information) in the output stream
$InformationPreference = 'Continue'

# Build the bot configuration object with endpoints, metadata, and timeouts
$bot                    = Initialize-BotByConfiguration -BotConfiguration $botConfiguration
$botAutomationDirectory = $botConfiguration.Directories.BotAutomationDirectory
$botAutomationFile      = $botConfiguration.Directories.BotAutomationFile
$botBase64Content       = $botConfiguration.Metadata.BotBase64Content
$botCallbackJob         = $bot.CallbackJob
$botOutputDirectory     = $botConfiguration.Directories.BotOutputDirectory
$botCalculatedName      = $botConfiguration.Metadata.BotName
$botEntryPoint          = $botConfiguration.Endpoints.BotEntryPointPrefix
$errorsDirectory        = $botConfiguration.Directories.BotErrorsDirectory
$instance               = $botConfiguration.Metadata.BotId
$outputDirectory        = $botConfiguration.Directories.BotOutputDirectory
$saveErrors             = $botConfiguration.Settings.SaveErrors
$saveResponse           = $botConfiguration.Settings.SaveResponse

# Display startup message and instructions
Write-Host
Write-Host "Starting bot '$($BotName)' process.`nPress [Ctrl] + [C] to stop bot.`n"

try {
    # Check if the automation file exists; if not, wait and retry
    if (-Not (Test-BotFile -BotFilePath $botAutomationFile)) {
        Write-Log `
            -Level   Warning `
            -Message "(Start-CronBot) File 'automation.json' not found in '$($botAutomationDirectory)'. Waiting for next interval." `
            -UseColor
        exit 0
    }

    # Generate a unique session ID based on current timestamp
    $session = (Get-Date).ToString("yyyyMMddHHmmssfff")
    
    # Build file paths for saving output and errors
    $outputFilePath = [IO.Path]::Combine($OutputDirectory, "$($BotName)-$($session).json")
    $errorFilePath  = [IO.Path]::Combine($ErrorsDirectory, "$($BotName)-$($session).json")
    
    # Notify the hub that the bot is now Working, suppressing any output
    Update-BotStatus -BotId $instance -HubUri $HubUri -Status "Working" | Out-Null

    # Send the automation request to the bot and capture its response
    $botResponse = Send-BotAutomationRequest `
        -HubUri         $HubUri `
        -Base64Request  $botBase64Content

    # Normalize status code to a string array, even if it's just one item
    $statusCodes = @(@($botResponse.StatusCode) | Where-Object { -not [string]::IsNullOrWhiteSpace("$($_)") })
    
    # Safely pick last valid status code
    if ($statusCodes.Length -gt 0) {
        $botStatusCodeValue = "$($statusCodes[-1])"
    } else {
        Write-Log `
            -Level   Warning `
            -Message "(Start-CronBot) Status code array contains only empty/null values. Falling back to status code 500." `
            -UseColor
        $botStatusCodeValue = "500"
    }
    
    # Try parsing explicitly
    $botStatusCode = 0
    if (-not [int]::TryParse($botStatusCodeValue, [ref]$botStatusCode)) {
        Write-Log `
            -Level   Warning `
            -Message "(Start-CronBot) Failed parsing status code from: $($botStatusCodeValue). Falling back to status code 500." `
            -UseColor
    }
    
    # Normalize status code to if failed to parse
    $botStatusCode = if($botStatusCode -eq 0) { 500 } else { $botStatusCode }
    
    # If the bot returned an error and we should save errors, write to error file
    if ($botStatusCode -ge 400 -and $SaveErrors) {
        Set-Content -Value $botResponse.JsonValue -Path $errorFilePath
    }
    
    # If the bot succeeded and we should save responses, write to output file
    if ($botStatusCode -eq 200 -and $SaveResponse) {
        Set-Content -Value $botResponse.JsonValue -Path $outputFilePath
    }

    # Notify the hub that the bot is now Ready, suppressing any output
    Update-BotStatus -BotId $instance -HubUri $HubUri -Status "Completed" | Out-Null
}
catch {
    # Catch any unexpected errors that occurred during bot execution
    # Log the full error message as a warning to highlight the failure
    Write-Log -Level Warning -Message "(Start-CronBot) Unexpected error occurred: $($_)" -UseColor
}
finally {
    # Log that cleanup of the HttpListener is starting
    Write-Log -Level Debug -Message "(Start-CronBot) Performing cleanup and shutting down the HttpListener." -UseColor

    # Check if the job object or its HttpListener is null (e.g., initialization may have failed)
    # If so, skip shutdown and exit cleanly
    if($null -eq $botCallbackJob -or $null -eq $botCallbackJob.HttpListener) {
        exit 0
    }

    # Assign the HttpListener instance for cleanup
    $listner = $botCallbackJob.HttpListener

    try {
        # Attempt to stop, close, and abort the HttpListener gracefully
        $listner.Stop()
        $listner.Close()
        $listner.Abort()

        # Log successful shutdown
        Write-Log -Level Information -Message "(Start-CronBot) HttpListener stopped and disposed successfully." -UseColor
    }
    catch {
        # Log any issues that occur while shutting down the listener for debugging purposes
        Write-Log -Level Debug -Message "(Start-CronBot) $($_.Exception.Message)" -UseColor
    }
}
