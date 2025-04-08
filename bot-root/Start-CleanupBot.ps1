<#
.SYNOPSIS
    Automated cleanup script for removing old files from specified directories on a BotVolume.

.DESCRIPTION
    This script scans the specified BotVolume for target directories ("archive", "output", "errors") 
    and for temporary directories named ".tmp". It retains only the newest files up to the 
    specified NumberOfFilesToRetain per target folder and removes the rest. The script runs continuously, 
    pausing between cycles as defined by the IntervalTime parameter.

.PARAMETER BotVolume
    The path to the volume where the cleanup will be performed. This parameter is mandatory.

.PARAMETER NumberOfFilesToRetain
    Specifies the number of newest files to retain per target folder. Must be an integer greater than 0.

.PARAMETER IntervalTime
    Specifies the time interval (in seconds) between cleanup cycles. Must be an integer greater than 0.

.PARAMETER Docker
    Switch to run the script inside a Docker container. When specified, the script will launch a Docker container
    using the given parameters and then exit.

.EXAMPLE
    .\CleanupScript.ps1 -BotVolume "D:\BotData" -NumberOfFilesToRetain 10 -IntervalTime 300

    This command runs the cleanup on the D:\BotData volume, retaining the 10 newest files in each target folder, 
    and waits 5 minutes between each run.

.NOTES
    Designed to be run manually (or via a scheduling mechanism) for continuous monitoring and automated cleanup.
#>
param (
    [Parameter(Mandatory=$true)]
    [string]$BotVolume,

    [ValidateRange(1, [int]::MaxValue)]
    [Parameter(Mandatory=$true)]
    [int]$NumberOfFilesToRetain,

    [ValidateRange(1, [int]::MaxValue)]
    [Parameter(Mandatory=$true)]
    [int]$IntervalTime,

    [Parameter(Mandatory = $false)]
    [switch]$Docker
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
    Write-Host "$($Message) $($isoNextAutomation)"
    Write-Host "$([System.Environment]::NewLine)Press [Ctrl] + [C] to stop the script."

    # Pause execution for the specified interval.
    Start-Sleep -Seconds $IntervalTime
}

if ($Docker) {
    $botName = "g4-partition-cleanup-bot"
    try {
        Write-Verbose "Docker switch is enabled. Preparing to launch Docker container for bot '$($botName)'."
        Write-Verbose "Building the Docker command from the specified parameters."
        $cmdLines = @(
            "run -d -v `"$($BotVolume):/bots`"",
            " -e CLEANUP_BOT_NUNBER_OF_FILES=$($NumberOfFilesToRetain)",
            " -e CLEANUP_BOT_INTERVAL_TIME=$($IntervalTime)",
            " --name `"$($botName)-$([guid]::NewGuid())`" g4-partition-cleanup-bot:latest"
        )
        
        Write-Verbose "Joining command parts into a single Docker command string."
        $dockerCmd = $cmdLines -join [string]::Empty

        Write-Host "Invoking Docker with the following command:$([System.Environment]::NewLine)docker $($dockerCmd)"
        $process = Start-Process -FilePath "docker" -ArgumentList $dockerCmd -PassThru
        $process.WaitForExit(60000)

        Write-Host "Docker container '$($botName)' started successfully."
        Exit 0
    }
    catch {
        Write-Error "Failed to start Docker container '$($botName)': $($_.Exception.GetBaseException())"
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

Write-Verbose "Starting cleanup process on BotVolume: $($BotVolume)"
Write-Verbose "Will retain the newest $($NumberOfFilesToRetain) files per target folder."

while ($true) {
    # Process target directories (archive, output, errors)
    try {
        Write-Verbose "Verifying the existence of the BotVolume at path '$($BotVolume)'"
        if (-not (Test-Path -Path $BotVolume)) {
            Clear-Host
            Write-Host "The specified BotVolume '$($BotVolume)' does not exist. Please verify the provided path." -ForegroundColor Red
            Wait-Interval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
            continue
        }

        Write-Verbose "Scanning for archive, output, and errors directories..."
        $targetDirs = Get-ChildItem -Path $BotVolume -Directory -Recurse | Where-Object { $_.Name -in @("archive", "output", "errors") }
        $totalDirs  = $targetDirs.Count

        if ($totalDirs -eq 0) {
            Clear-Host
            Wait-Interval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
            continue
        }

        $dirCounter = 0
        foreach ($dir in $targetDirs) {
            $dirCounter++
            $dirsPercentComplete = ($dirCounter / $totalDirs) * 100
            Write-Progress `
                -Activity        "Processing Directories" `
                -Status          "Processing Directory $($dir.FullName)" `
                -PercentComplete $dirsPercentComplete `
                -Id              1

            # Get files to be removed
            $targetFiles        = Get-ChildItem -Path $dir.FullName -File | Sort-Object LastWriteTime -Descending
            $totalFiles         = $targetFiles.Count

            if ($totalFiles -le $NumberOfFilesToRetain) {
                Write-Verbose "Nothing to remove in: $($dir.FullName)"
                continue
            }

            $filesToRemove      = $targetFiles[$NumberOfFilesToRetain..($totalFiles - 1)]
            $totalFilesToRemove = $filesToRemove.Count

            if ($totalFilesToRemove -eq 0) {
                Write-Verbose "Nothing to remove in: $($dir.FullName)"
                continue
            }

            $fileCounter = 0
            foreach ($file in $filesToRemove) {
                $fileCounter++
                $filesPercentComplete = ($fileCounter / $totalFilesToRemove) * 100
                Write-Progress `
                    -Activity        "Processing Files" `
                    -Status          "Removing File: $($file.FullName)" `
                    -PercentComplete $filesPercentComplete `
                    -Id 100 `
                    -ParentId 1

                try {
                    Remove-Item -Path $file.FullName -Force
                }
                catch {
                    Write-Verbose "Error removing file '$($file.FullName)': $($_.Exception.GetBaseException().Message)"
                }
            }
        }        
    }
    catch {
        Write-Verbose "Error during directories processing: $($_.Exception.GetBaseException().Message)"
    }
    finally {
        Write-Progress -Activity "Processing Files"       -Completed -Id 100 -ParentId 1
        Write-Progress -Activity "Processing Directories" -Completed -Id 1
    }

    # Process temporary directories (.tmp)
    try {
        Write-Verbose "Scanning for .tmp directories..."
        $tmpDirs      = Get-ChildItem -Path $BotVolume -Directory -Recurse | Where-Object { $_.Name -eq ".tmp" }
        $totalTmpDirs = $tmpDirs.Count

        if ($totalTmpDirs -eq 0) {
            Clear-Host
            Wait-Interval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
            continue
        }

        $tmpDirCounter = 0
        foreach ($tmpDir in $tmpDirs) {
            $tmpDirCounter++
            $tmpDirsPercentComplete = ($tmpDirCounter / $totalTmpDirs) * 100
            Write-Progress `
                -Activity        "Processing Temporary Directories" `
                -Status          "Processing Temporary Directory $($tmpDir.FullName)" `
                -PercentComplete $tmpDirsPercentComplete `
                -Id              2

            $targetFiles = Get-ChildItem -Path $tmpDir.FullName -File | Sort-Object LastWriteTime -Descending
            $totalFiles  = $targetFiles.Count

            if ($totalFiles -eq 0) {
                Write-Verbose "Nothing to remove in: $($tmpDir.FullName)"
                continue
            }

            $fileCounter = 0
            foreach ($file in $targetFiles) {
                $fileCounter++
                $filesPercentComplete = ($fileCounter / $totalFiles) * 100
                Write-Progress `
                    -Activity        "Processing Temporary Files" `
                    -Status          "Removing Temporary File: $($file.FullName)" `
                    -PercentComplete $filesPercentComplete `
                    -Id              200 `
                    -ParentId        2

                try {
                    Remove-Item -Path $file.FullName -Force
                }
                catch {
                    Write-Verbose "Error removing file '$($file.FullName)': $($_.Exception.GetBaseException().Message)"
                }
            }
        }
    }
    catch {
        Write-Verbose "Error during temporary directories processing: $($_.Exception.GetBaseException().Message)"
    }
    finally {
        Write-Progress -Activity "Processing Temporary Files" -Completed -Id 200 -ParentId 2
        Write-Progress -Activity "Processing Temporary Directories" -Completed -Id 2
    }

    Clear-Host
    Wait-Interval -IntervalTime $IntervalTime -Message "Next bot invocation scheduled at"
}
