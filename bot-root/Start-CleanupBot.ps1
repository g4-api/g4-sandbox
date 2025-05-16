param (
    [CmdletBinding()]
    [Parameter(Mandatory = $false)] [string] $BotId,
    [Parameter(Mandatory = $true)]  [string] $BotVolume,
    [Parameter(Mandatory = $false)] [string] $CallbackIngress,
    [Parameter(Mandatory = $false)] [string] $CallbackUri,
    [Parameter(Mandatory = $true)]  [string] $HubUri,
    [Parameter(Mandatory = $true)]  [int]    $IntervalTime,
    [Parameter(Mandatory = $true)]  [int]    $NumberOfFilesToRetain,
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
    -BotName             'volume-cleanup-bot' `
    -BotType             'cleanup-bot' `
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
            " -e CALLBACK_INGRESS=`"$($botConfiguration.Endpoints.BotCallbackIngress)`""
            " -e CALLBACK_URI=`"$($botConfiguration.Endpoints.BotCallbackUri)`""
            " -e CLEANUP_BOT_INTERVAL_TIME=`"$($IntervalTime)`""
            " -e CLEANUP_BOT_NUNBER_OF_FILES=$($NumberOfFilesToRetain)"
            " -e HUB_URI=`"$($botConfiguration.Endpoints.HubUri)`""
            " -e TOKEN=`"$($botConfiguration.Metadata.Token)`""
        )
        
        # Publish port and assign unique container name
        $cmdLines += " -p $($botConfiguration.Endpoints.CallbackPort):$($botConfiguration.Endpoints.CallbackPort)"

        # Set container name and tag
        $cmdLines += " --name `"$($botConfiguration.Metadata.BotName)-$([guid]::NewGuid())`" g4-partition-cleanup-bot:latest"

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
        Write-Log -Level Critical -UseColor -Message "Failed to start Docker container '$('volume-cleanup-bot')': $($_.Exception.GetBaseException())"
    }
    finally{
        Exit 0
    }
}

# Configure PowerShell to display informational messages (Write-Information) in the output stream
$InformationPreference = 'Continue'

# Build the bot configuration object with endpoints, metadata, and timeouts
$bot                = Initialize-BotByConfiguration -BotConfiguration $botConfiguration
$botAutomationFile  = $botConfiguration.Directories.BotAutomationFile
$botBase64Content   = $botConfiguration.Metadata.BotBase64Content
$botCallbackJob     = $bot.CallbackJob
$botOutputDirectory = $botConfiguration.Directories.BotOutputDirectory
$botCalculatedName  = $botConfiguration.Metadata.BotName
$botEntryPoint      = $botConfiguration.Endpoints.BotEntryPointPrefix
$errorsDirectory    = $botConfiguration.Directories.BotErrorsDirectory
$instance           = $botConfiguration.Metadata.BotId
$outputDirectory    = $botConfiguration.Directories.BotOutputDirectory
$saveErrors         = $botConfiguration.Settings.SaveErrors
$saveResponse       = $botConfiguration.Settings.SaveResponse

# Definitions: grab the ScriptBlock for each function so they can be injected into a child runspace
$sendBotAutomationRequest = (Get-Command -Name 'Send-BotAutomationRequest').ScriptBlock
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
        $message   = "$($s[$e.Index].Message)"
        $message   = if($message.Contains(" - WRN:")) { $message } else { "$($timestamp) - WRN: (Start-CleanupBot) $($s[$e.Index].Message)" }
        
        [Console]::ForegroundColor = [ConsoleColor]::Yellow
        [Console]::WriteLine($message)
        [Console]::ResetColor()
    })

# Only wire up informational relaying if the session is configured to show Information streams
if ($InformationPreference -eq 'Continue') {
        # Relay informational messages from the runspace
        $powerShell.Streams.Information.add_DataAdded({
            param($s, $e)

            $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $message   = "$($s[$e.Index].MessageData)"
            $message   = if($message.Contains(" - INF:")) { $message } else { "$($timestamp) - INF: (Start-CleanupBot) $($s[$e.Index].MessageData)" }

            [Console]::WriteLine($message)
        })
    }

# Add the script to the runspace, passing in all helper scriptblocks and parameters
$powerShell.AddScript({
    param(
        $BotCallbackJob,
        $BotId,
        $BotVolume,
        $HubUri,
        $IntervalTime,
        $NumberOfFilesToRetain,
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
            # Update the bot status to 'Working' in the hub
            & $UpdateBotStatus -BotId $BotId -HubUri $HubUri -Status "Working" | Out-Null

            # Verify the BotVolume directory exists before processing
            if (-not (Test-Path -Path $BotVolume)) {
                Write-Warning "The specified BotVolume '$($BotVolume)' does not exist. Please verify the provided path."
                & $WaitInterval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
                continue
            }

            # Retrieve target directories recursively (archive, output, errors, extractions)
            $targetDirs = Get-ChildItem -Path $BotVolume -Directory -Recurse | Where-Object { $_.Name -in @("archive", "output", "errors", "extractions") }
            $totalDirs  = $targetDirs.Count

            # If no matching directories found, wait for the next interval
            if ($totalDirs -eq 0) {
                & $WaitInterval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
                continue
            }

            # Iterate through each matching directory
            foreach ($dir in $targetDirs) {
                # Ensure directory still exists before proceeding
                if (-not (Test-Path -Path $dir.FullName)) {
                    continue
                }

                # Get all files sorted by LastWriteTime descending
                $targetFiles = Get-ChildItem -Path $dir.FullName -File | Sort-Object LastWriteTime -Descending
                $totalFiles  = $targetFiles.Count

                # Skip directories that don't exceed the file retention threshold
                if ($totalFiles -le $NumberOfFilesToRetain) {
                    Write-Debug "Nothing to remove in: $($dir.FullName)"
                    continue
                }

                # Select files to remove beyond the retention threshold
                $filesToRemove      = $targetFiles[$NumberOfFilesToRetain..($totalFiles - 1)]
                $totalFilesToRemove = $filesToRemove.Count

                # If no files are marked for removal, skip
                if ($totalFilesToRemove -eq 0) {
                    Write-Debug "Nothing to remove in: $($dir.FullName)"
                    continue
                }

                # Remove each file with progress tracking
                foreach ($file in $filesToRemove) {
                    try {
                        # Remove file with force
                        Remove-Item -Path $file.FullName -Force
                    }
                    catch {
                        # Log error if file deletion fails
                        Write-Warning "Error removing file '$($file.FullName)': $($_.Exception.GetBaseException().Message)"
                    }
                }
            }        
        }
        catch {
            # Log any error that occurs during directory processing
            Write-Warning "Error during directories processing: $($_.Exception.GetBaseException().Message)"
        }

        try {
            # Find all .tmp directories recursively under BotVolume
            $tmpDirs      = Get-ChildItem -Path $BotVolume -Directory -Recurse | Where-Object { $_.Name -eq ".tmp" }
            $totalTmpDirs = $tmpDirs.Count

            # Skip if no .tmp directories found
            if ($totalTmpDirs -eq 0) {
                & $WaitInterval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
                continue
            }

            # Process each .tmp directory individually
            foreach ($tmpDir in $tmpDirs) {
                # Get files in the .tmp directory sorted by LastWriteTime descending
                $targetFiles = Get-ChildItem -Path $tmpDir.FullName -File | Sort-Object LastWriteTime -Descending
                $totalFiles  = $targetFiles.Count

                # Skip empty directories
                if ($totalFiles -eq 0) {
                    Write-Debug "Nothing to remove in: $($tmpDir.FullName)"
                    continue
                }

                # Remove each file in the temporary directory
                foreach ($file in $targetFiles) {
                    try {
                        # Attempt to remove the temporary file
                        Remove-Item -Path $file.FullName -Force
                    }
                    catch {
                        # Log if file removal fails
                        Write-Warning "Error removing file '$($file.FullName)': $($_.Exception.GetBaseException().Message)"
                    }
                }
            }
        }
        catch {
            # Log any error that occurs during temporary directory processing
            Write-Warning "Error during temporary directories processing: $($_.Exception.GetBaseException().Message)"
        }

        try {
            # Update the bot status to 'Ready' in the hub
            & $UpdateBotStatus -BotId $BotId -HubUri $HubUri -Status "Ready" | Out-Null

            # Wait before the next scheduled run
            & $WaitInterval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
        }
        catch {
            # Log any error that occurs during teardown
            Write-Warning $_.Exception.Message
        }
    }
}) | Out-Null

# Initialize the bot HTTP listener
$listener = New-Object System.Net.HttpListener

# Add arguments matching the runspace script's param() order
$powerShell.AddArgument($botCallbackJob)        | Out-Null
$powerShell.AddArgument($instance)              | Out-Null
$powerShell.AddArgument($BotVolume)             | Out-Null
$powerShell.AddArgument($HubUri)                | Out-Null
$powerShell.AddArgument($IntervalTime)          | Out-Null
$powerShell.AddArgument($NumberOfFilesToRetain) | Out-Null
$powerShell.AddArgument($updateBotStatus)       | Out-Null
$powerShell.AddArgument($waitInterval)          | Out-Null

# Start the runspace asynchronously, capturing the IAsyncResult
$async = $powerShell.BeginInvoke($inputBuffer, $outputBuffer)

# Display startup message and instructions
Write-Host "`nStarting cleanup process on volume: $($BotVolume).`nWill retain the newest $($NumberOfFilesToRetain) files per target folder.`n"

# Loop until the callback listener runspace completes
while ((-not $bot.CallbackJob.AsyncResult.IsCompleted -and $bot.CallbackJob.Runner.InvocationStateInfo.State -eq 'Running') -and (-not $async.IsCompleted -and $powerShell.InvocationStateInfo.State -eq 'Running')) {
    Start-Sleep -Seconds 3
}
