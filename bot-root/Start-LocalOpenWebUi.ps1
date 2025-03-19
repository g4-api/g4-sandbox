<#
.SYNOPSIS
    Activates and runs the 'open-webui' service within WSL with error handling.

.DESCRIPTION
    This script determines the parent folder of its location and sets it as the working directory.
    It then constructs and executes a WSL command that activates a Python virtual environment and 
    starts the 'open-webui' service. The script includes error handling to catch and display any issues.

.EXAMPLE
    .\Start-LocalOpenWebUi.ps1
#>
try {
    # Retrieve the parent directory of the script's current folder.
    $workingDirectory = Split-Path $PSScriptRoot -Parent
    Write-Host "Working Directory: $workingDirectory"
    
    # Change the current location to the working directory.
    Set-Location -Path $workingDirectory

    # Define the WSL command to activate the virtual environment and run the 'open-webui' service.
    $wslCommand = "source open-webui/bin/activate && open-webui serve"

    # Execute the WSL command via bash within WSL.
    # -PassThru returns a process object so we can check the exit code.
    # -ErrorAction Stop ensures any error stops execution and is caught by the catch block.
    $process = Start-Process -FilePath wsl -ArgumentList "bash -c `"$wslCommand`"" -PassThru -ErrorAction Stop

    # If the process exits with a non-zero exit code, throw an error.
    if ($process.ExitCode -ne 0) {
        throw "WSL command failed with exit code $($process.ExitCode)."
    }

    # Notify the user of a successful service start.
    Write-Host "'open-webui' service setup and execution completed successfully." -ForegroundColor Green
}
catch {
    # In case of any errors, output the error message.
    Write-Error "Error: $_"
}
