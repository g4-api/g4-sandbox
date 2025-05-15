param (
    [CmdletBinding()]
    [Parameter(Mandatory = $false)] [string] $BotId,
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
    -BotType             'file-listener-bot' `
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
            " -e DRIVER_BINARIES=`"$($botConfiguration.Endpoints.DriverBinaries)`""
            " -e HUB_URI=`"$($botConfiguration.Endpoints.HubUri)`""
            " -e INTERVAL_TIME=`"$($IntervalTime)`""
            " -e SAVE_ERRORS=`"$($botConfiguration.Settings.SaveErrors)`""
            " -e SAVE_RESPONSE=`"$($botConfiguration.Settings.SaveResponse)`""
            " -e TOKEN=`"$($botConfiguration.Metadata.Token)`""
        )
        
        # Publish port and assign unique container name
        $cmdLines += " -p $($botConfiguration.Endpoints.CallbackPort):$($botConfiguration.Endpoints.CallbackPort)"

        # Set container name and tag
        $cmdLines += " --name `"$($botConfiguration.Metadata.BotName)-$([guid]::NewGuid())`" g4-file-listener-bot:latest"

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
$bot                = Initialize-BotByConfiguration -BotConfiguration $botConfiguration
$archiveDirectory   = $botConfiguration.Directories.BotArchiveDirectory
$botAutomationFile  = $botConfiguration.Directories.BotAutomationFile
$botBase64Content   = $botConfiguration.Metadata.BotBase64Content
$botCallbackJob     = $bot.CallbackJob
$botOutputDirectory = $botConfiguration.Directories.BotOutputDirectory
$botCalculatedName  = $botConfiguration.Metadata.BotName
$botEntryPoint      = $botConfiguration.Endpoints.BotEntryPointPrefix
$errorsDirectory    = $botConfiguration.Directories.BotErrorsDirectory
$inputDirectory     = $botConfiguration.Directories.BotInputDirectory
$instance           = $botConfiguration.Metadata.BotId
$outputDirectory    = $botConfiguration.Directories.BotOutputDirectory
$saveErrors         = $botConfiguration.Settings.SaveErrors
$saveResponse       = $botConfiguration.Settings.SaveResponse

# Definitions: grab the ScriptBlock for each function so they can be injected into a child runspace
$getNextFile              = (Get-Command -Name 'Get-NextFile').ScriptBlock
$sendBotAutomationRequest = (Get-Command -Name 'Send-BotAutomationRequest').ScriptBlock
$setJsonData              = (Get-Command -Name 'Set-JsonData').ScriptBlock
$testBotFile              = (Get-Command -Name 'Test-BotFile').ScriptBlock
$updateBotStatus          = (Get-Command -Name 'Update-BotStatus').ScriptBlock
$waitInterval             = (Get-Command -Name 'Wait-Interval').ScriptBlock

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
        [Console]::WriteLine("$($timestamp) - WRN: (Start-FileListenerBot) $($s[$e.Index].Message)")
        [Console]::ResetColor()
    })

# Only wire up informational relaying if the session is configured to show Information streams
if ($InformationPreference -eq 'Continue') {
        # Relay informational messages from the runspace
        $powerShell.Streams.Information.add_DataAdded({
            param($s, $e)

            $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            [Console]::WriteLine("$($timestamp) - INF: (Start-FileListenerBot) $($s[$e.Index].MessageData)")
        })
    }

# Add the script to the runspace, passing in all helper scriptblocks and parameters
$powerShell.AddScript({
    param(
        $ArchiveDirectory,
        $BotAutomationFile,
        $BotBase64Content,
        $BotCallbackJob,
        $BotId,
        $BotName,
        $ErrorsDirectory,
        $GetNextFile,
        $HubUri,
        $InputDirectory,
        $IntervalTime,
        $OutputDirectory,
        $SaveErrors,
        $SaveResponse,
        $SendBotAutomationRequest,
        $SetJsonData,
        $TestBotFile,
        $UpdateBotStatus,
        $WaitInterval
    )

    # Enable debug, information, and verbose output for troubleshooting
    $DebugPreference       = 'Continue'
    $InformationPreference = 'Continue'
    $VerbosePreference     = 'Continue'

    # Loop until the callback listener runspace completes
    while((-not $BotCallbackJob.AsyncResult.IsCompleted -and $BotCallbackJob.Runner.InvocationStateInfo.State -eq 'Running')) {
        try {
            # Check if the automation file exists; if not, wait and retry
            if (-Not (& $TestBotFile -BotFilePath $BotAutomationFile)) {
                & $WaitInterval -Message "Next check scheduled at:" -IntervalTime $IntervalTime
                continue
            }

            # Generate a unique session ID based on current timestamp
            $session = (Get-Date).ToString("yyyyMMddHHmmssfff")

            # Searching for the next file to process
            $nextFile = & $GetNextFile `
                -InputDirectory   $InputDirectory `
                -ArchiveDirectory $ArchiveDirectory `
                -Session          $session `
                -Extensions       'csv','json'

            # If no valid file is found, log the reason and wait for the next check.
            if ($nextFile.StatusCode -gt 200) {
                & $WaitInterval -Message "Next check scheduled at:" -IntervalTime $IntervalTime
                continue
            }

            # Build file paths for saving output and errors
            $outputFilePath = [IO.Path]::Combine($OutputDirectory, "$($BotName)-$($session).json")
            $errorFilePath  = [IO.Path]::Combine($ErrorsDirectory, "$($BotName)-$($session).json")
            
            # Notify the hub that the bot is now Working, suppressing any output
            & $UpdateBotStatus -BotId $BotId -HubUri $HubUri -Status "Working" | Out-Null

            # Inject the formatted JSON data into the base64-encoded automation request
            # This returns a new Base64-encoded automation request with updated .dataSource field
            $BotBase64Content = & $SetJsonData -Base64AutomationRequest $BotBase64Content -JsonData $nextFile.Content

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
            }
            
            # If the bot succeeded and we should save responses, write to output file
            if ($botStatusCode -eq 200 -and $SaveResponse) {
                Set-Content -Value $botResponse.JsonValue -Path $outputFilePath
            }

            # Notify the hub that the bot is now Ready, suppressing any output
            & $UpdateBotStatus -BotId $BotId -HubUri $HubUri -Status "Ready" | Out-Null

            # Wait for the configured interval before the next iteration
            & $WaitInterval `
                -IntervalTime $IntervalTime `
                -Message "Next check scheduled at:"
        }
        catch {
            # Catch any unexpected errors, log a warning, and wait before retry
            Write-Warning "$($_)"
            & $WaitInterval `
                -IntervalTime $IntervalTime `
                -Message "Next check scheduled at:"
        }
    }
}) | Out-Null

# Initialize the bot HTTP listener
$listener = New-Object System.Net.HttpListener

# Add arguments matching the runspace script's param() order
$powerShell.AddArgument($archiveDirectory)         | Out-Null
$powerShell.AddArgument($botAutomationFile)        | Out-Null
$powerShell.AddArgument($botBase64Content)         | Out-Null
$powerShell.AddArgument($botCallbackJob)           | Out-Null
$powerShell.AddArgument($instance)                 | Out-Null
$powerShell.AddArgument($botCalculatedName)        | Out-Null
$powerShell.AddArgument($errorsDirectory)          | Out-Null
$powerShell.AddArgument($getNextFile)              | Out-Null
$powerShell.AddArgument($HubUri)                   | Out-Null
$powerShell.AddArgument($inputDirectory)           | Out-Null
$powerShell.AddArgument($IntervalTime)             | Out-Null
$powerShell.AddArgument($outputDirectory)          | Out-Null
$powerShell.AddArgument($saveErrors)               | Out-Null
$powerShell.AddArgument($saveResponse)             | Out-Null
$powerShell.AddArgument($sendBotAutomationRequest) | Out-Null
$powerShell.AddArgument($setJsonData)              | Out-Null
$powerShell.AddArgument($testBotFile)              | Out-Null
$powerShell.AddArgument($updateBotStatus)          | Out-Null
$powerShell.AddArgument($waitInterval)             | Out-Null

# Start the runspace asynchronously, capturing the IAsyncResult
$async = $powerShell.BeginInvoke($inputBuffer, $outputBuffer)

# Display startup message and instructions
Write-Host
Write-Host "Starting bot '$($BotName)' loop with '$($IntervalTime)' seconds interval.`nPress [Ctrl] + [C] to stop bot.`n"

# Loop until the callback listener runspace completes
while ((-not $bot.CallbackJob.AsyncResult.IsCompleted -and $bot.CallbackJob.Runner.InvocationStateInfo.State -eq 'Running') -and (-not $async.IsCompleted -and $powerShell.InvocationStateInfo.State -eq 'Running')) {
    Start-Sleep -Seconds 3
}
