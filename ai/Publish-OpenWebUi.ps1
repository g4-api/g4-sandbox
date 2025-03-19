<#
.SYNOPSIS
    Sets up a Python virtual environment and runs the 'open-webui' service within WSL.

.DESCRIPTION
    This script navigates to the specified sandbox directory, creates a Python virtual environment
    named 'open-webui', activates it, force-upgrades the 'open-webui' package, and starts the service.
    All commands are executed within WSL using a single Bash command.

.PARAMETER SandboxDirectory
    Specifies the directory path where the virtual environment will be set up.
    This should be provided as a WSL-compatible path (e.g., "/mnt/e/G4/g4-sandbox").

.EXAMPLE
    .\Deploy-OpenWebUi.ps1 -SandboxDirectory "/mnt/e/G4/g4-sandbox"
#>
param (
    [Parameter(Mandatory = $true)]
    [string]$SandboxDirectory
)

try {
    # Construct the WSL command that will:
    # 1. Change directory to the specified SandboxDirectory.
    # 2. Create a Python virtual environment named 'open-webui'.
    # 3. Activate the virtual environment.
    # 4. Force-upgrade and reinstall the 'open-webui' package.
    $wslCommand = "cd $SandboxDirectory && python3 -m venv open-webui && source open-webui/bin/activate && pip install --upgrade --force-reinstall open-webui"

    # Execute the WSL command using Bash within the WSL environment.
    # -PassThru: Returns the process object so we can check the exit code.
    # -ErrorAction Stop: Stops the script and jumps to the catch block if an error occurs.
    $process = Start-Process -FilePath wsl -ArgumentList "bash -c `"$wslCommand`"" -PassThru -ErrorAction Stop

    # Check if the process exited with a non-zero exit code, indicating an error.
    if ($process.ExitCode -ne 0) {
        throw "WSL command failed with exit code $($process.ExitCode)."
    }

    # Inform the user that the service setup and execution completed successfully.
    Write-Host "'open-webui' service setup and execution completed successfully." -ForegroundColor Green
}
catch {
    # Output any error that occurred during execution.
    Write-Error "Error: $_"
}
