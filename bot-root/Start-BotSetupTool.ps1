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

function Resolve-Shell {
    <#
    .SYNOPSIS
        Determines the appropriate shell executable based on the operating system.

    .DESCRIPTION
        This function checks the platform of the operating system and returns the appropriate
        shell command to use. On Unix-like systems, it returns "pwsh" (PowerShell Core), and on
        Windows, it returns "powershell".

    .OUTPUTS
        A string representing the shell executable ("powershell" or "pwsh").
    #>

    Write-Verbose "Default shell set to 'powershell' for Windows."
    $shell = "powershell"

    # Check if the operating system is Unix-based.
    if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Unix) {
        Write-Verbose "Unix platform detected. Using 'pwsh' for PowerShell Core."
        $shell = "pwsh"
    }

    Write-Verbose "Resolved shell: $shell"
    return $shell
}

function Show-Logo {
    <#
    .SYNOPSIS
        Displays an ASCII art logo along with a title and version information.

    .DESCRIPTION
        The Show-Logo function prints an ASCII art logo to the console, displays version
        and branding details, and then prints a custom title in cyan color.

    .PARAMETER Title
        The text title to display after the logo.

    .EXAMPLE
        Show-Logo -Title "Main Menu"
        # This command prints the logo, version, and the title "Main Menu" in cyan.
    #>
    param(
        [string]$Title
    )

    # Display each line of the ASCII art logo
    Write-Host "  ____ _  _   ____        _   ____       _                " 
    Write-Host " / ___| || | | __ )  ___ | |_/ ___|  ___| |_ _   _ _ __   "
    Write-Host "| |  _| || |_|  _ \ / _ \| __\___ \ / _ \ __| | | | '_ \  "
    Write-Host "| |_| |__   _| |_) | (_) | |_ ___) |  __/ |_| |_| | |_) | "
    Write-Host " \____|  |_| |____/ \___/ \__|____/ \___|\__|\__,_| .__/  "
    Write-Host "                                                  |_|     "

    # Display version and branding information
    Write-Host "G4 API Engine - Bots Setup Tool v1.0                      "
    Write-Host "Powered by G4 API Engine                                  "
    Write-Host "                                                          "

    # Display the provided title in cyan for emphasis
    Write-Host "$Title" -ForegroundColor Cyan
    Write-Host "                                                          "
}

function Show-Menu {
    <#
    .SYNOPSIS
        Displays a menu with a title and a list of options for user selection.

    .DESCRIPTION
        This function clears the screen, displays a title, lists options, and prompts the user for a choice.
        Based on the user's input, it executes the corresponding action. If the user enters 0, the menu exits.
        The function also supports displaying submenu options if indicated by the $IsSubMenu switch.

    .PARAMETER Title
        The title of the menu to be displayed at the top.

    .PARAMETER Options
        An array of strings representing the menu options that the user can choose from.

    .EXAMPLE
        Show-Menu -Title "Main Menu" -Options @("Option 1", "Option 2", "Option 3")
    #>
    param(
        [string]  $Title,
        [string[]]$Options
    )

    # Loop indefinitely until the user chooses to exit the menu
    while ($true) {
        # Clear the console for a fresh display of the menu
        Clear-Host

        # Display the menu title in cyan
        Show-Logo -Title $Title

        # Loop through each provided option and display it with an associated number
        for ($i = 0; $i -lt $Options.Length; $i++) {
            Write-Host "$($i + 1)) $($Options[$i])"
        }
        # Always provide a "Go Back" option as 0 to exit the menu or go back to a previous menu level
        Write-Host "0) Go Back"
        Write-Host ""

        # Prompt the user for input
        $choice = Read-Host "Enter your choice"

        # Check if the user wants to exit the menu
        if ($choice -eq "0") {
            break
        }
        # Validate that the input is an integer and within the range of available options
        elseif ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $Options.Length) {
            # Determine the selected option based on the user's input
            $selectedOption = $Options[$choice - 1]

            # Execute the appropriate action based on the selected option
            switch ($selectedOption) {
                "Initialize a New G4-Bot Partition" {
                    Start-NewPartitionWizard
                }
                "Launch a New G4-Bot" {
                    Show-LaunchBotSubmenu
                }
                "Launch Environment" {
                    Show-LaunchEnvironmentSubmenu
                }
                "Build G4-Bot Docker Image" {
                    Show-DockerImageSubmenu
                }
                "Update Driver" {
                    Show-UpdateDriverSubmenu
                }
                "Utilities" {
                    Show-UtilitiesSubmenu
                }
                default {
                    # Do nothing
                }
            }
        }
        else {
            # Prompt the user to press any key to return to the previous menu
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Write-Host "Press any key to return to the previous menu..."
            Read-Host
        }
    }
}

function Show-Wizard {
    <#
    .SYNOPSIS
        Displays an interactive wizard to collect parameters from the user.

    .DESCRIPTION
        The function presents a title and a series of prompts defined by the
        $WizardParameters array (each element is a hashtable with keys: Name,
        Description, Default, Mandatory, EnvironmentValue, and Type). It collects input for each parameter,
        applying the following rules:
          - If the user provides a value, that value is used.
          - If no value is provided:
              * For optional parameters: if an EnvironmentValue exists then it is used; otherwise, the Default is used.
              * For mandatory parameters: if an EnvironmentValue exists then it is used; otherwise, the Default is used.
                If no value results, the wizard continues to prompt until a non-empty value is given.
        After collecting values, any extra parameters from $ExtraParams are merged into the collected parameters,
        and then the specified script ($ScriptToRun) is executed using the collected parameters.
        Instead of building a dictionary of parameters, this version creates an array where each element
        is formatted as "-Parameter Value" (with additional formatting based on type).
        For invocation, the parameters are joined into a single string and passed as an argument
        to the script using Start-Process.

    .PARAMETER Title
        The title displayed at the top of the wizard.

    .PARAMETER WizardParameters
        An array of hashtables, each containing:
            - Name: The parameter name.
            - Description: A short description of the parameter.
            - Default: The default value if no input is provided.
            - Mandatory: A flag indicating if the parameter is required.
            - EnvironmentValue: An alternative default value (e.g., from the environment) that takes precedence over the Default.
            - Type: The type of parameter. Supported values are "string" and "switch".

    .PARAMETER ScriptToRun
        The script to execute after collecting the parameters.

    .PARAMETER ExtraParams
        An optional hashtable of extra parameters to merge into the collected parameters.

    .EXAMPLE
        $params = @(
            @{
                Name             = "Path"
                Description      = "The target directory"
                Default          = "C:\Temp"
                Mandatory        = $true
                EnvironmentValue = $env:TARGET_DIR
                Type             = "string"
            },
            @{
                Name             = "Force"
                Description      = "Force operation"
                Default          = "N"
                Mandatory        = $false
                EnvironmentValue = $null
                Type             = "switch"
            }
        )
        Show-Wizard -Title "Example Wizard" -WizardParameters $params -ScriptToRun "./Do-Something.ps1"
    #>
    param(
        [string]   $Title,
        [array]    $WizardParameters,
        [string]   $ScriptToRun,
        [hashtable]$ExtraParams = @{}
    )

    # Clear the screen and display the wizard title.
    Clear-Host
    Show-Logo -Title $Title

    # Determine shell type.
    $shell = Resolve-Shell

    # Initialize an empty collection for the parameters.
    $parametersCollection = @("-File $($ScriptToRun)")

    # Loop through each wizard parameter to collect input.
    foreach ($wizardParameter in $WizardParameters) {
        do {
            # Determine the effective default value.
            if (-not [string]::IsNullOrWhiteSpace($wizardParameter.EnvironmentValue)) {
                $effectiveDefault = $wizardParameter.EnvironmentValue
            }
            else {
                $effectiveDefault = $wizardParameter.Default
            }

            # Build the prompt message.
            if ($wizardParameter.Mandatory) {
                $prompt = "$($wizardParameter.Name) (Mandatory"
                if (-not [string]::IsNullOrWhiteSpace($effectiveDefault)) {
                    $prompt += ", default: $effectiveDefault"
                }
                $prompt += ")"
            }
            else {
                $prompt = "$($wizardParameter.Name) (Optional"
                if (-not [string]::IsNullOrWhiteSpace($effectiveDefault)) {
                    $prompt += ", default: $effectiveDefault"
                }
                $prompt += ")"
            }

            Write-Host "$prompt - $($wizardParameter.Description)"
            $inputValue = Read-Host "Enter value"

            if (-not [string]::IsNullOrWhiteSpace($inputValue)) {
                $content = $inputValue
            }
            else {
                $content = $effectiveDefault
            }
            
            if ($wizardParameter.Mandatory -and [string]::IsNullOrWhiteSpace($content)) {
                Write-Host "This parameter is mandatory. Please provide a value." -ForegroundColor Red
                $content = $null
            }
        } while ([string]::IsNullOrWhiteSpace($content))
        
        # Build the parameter string based on type.
        switch ($wizardParameter.Type.ToLower()) {
            "switch" {
                # For a switch parameter, if the value is "false" (case-insensitive), ignore it.
                if ($content -match "^(false)$") {
                    Write-Verbose "Ignoring switch parameter '$($wizardParameter.Name)' because its value is false."
                    continue
                }
                else {
                    # For a switch, add it as a switch (without a value).
                    $parametersCollection += "-$($wizardParameter.Name)"
                }
            }
            "string" {
                # Wrap the content in quotes.
                $parametersCollection += "-$($wizardParameter.Name) `"$content`""
            }
            default {
                # For other types, add without additional formatting.
                $parametersCollection += "-$($wizardParameter.Name) $content"
            }
        }

        Write-Host ""
    }

    # Merge any extra parameters into the parameters collection.
    foreach ($key in $ExtraParams.Keys) {
        $parametersCollection += "-$key $($ExtraParams[$key])"
    }

    # Display the collected parameters for confirmation.
    Write-Host "Wizard complete.`nCollected parameters:" -ForegroundColor Green
    $parametersCollection | ForEach-Object { Write-Host $_ }
    Write-Host ""

    Write-Host "Invoking script: $ScriptToRun" -ForegroundColor Cyan
    Write-Host ""

    # Join the parameters collection into a single string.
    $argumentList = [string]::Join(' ', $parametersCollection)
    
    try {
        # Start the process using the determined shell.
        $process = Start-Process -FilePath $shell -ArgumentList $argumentList -PassThru
    }
    catch {
        Write-Error "Error executing script $($ScriptToRun): $($_.Exception.GetBaseException())"
    }

    Write-Host ""
    Write-Host "Press any key to return to the previous menu..."
    Read-Host
}

function Show-DockerImageSubmenu {
    <#
    .SYNOPSIS
        Displays a submenu to select a Docker image build option for G4-Bot.

    .DESCRIPTION
        This function presents a list of available Docker image options (each defined as an ordered hashtable)
        and prompts the user to select one. Each option includes the Dockerfile path, default Docker image tag,
        and the bot name. When an option is selected, it builds a wizard parameter hashtable for the image tag
        and calls the Show-Wizard function with the appropriate parameters to initiate the build process.
    The user can also choose to go back by entering "0".

    .OUTPUTS
        None. The function directly displays the menu and calls another script based on user input.
    #>

    # Define Docker image options as an array of ordered hashtables with keys sorted alphabetically.
    $dockerOptions = @(
        [ordered]@{
            Dockerfile  = "docker/g4-cron-bot.Dockerfile"
            DefaultTag  = "g4-cron-bot:latest"
            Name        = "Cron Bot"
        },
        [ordered]@{
            Dockerfile  = "docker/g4-file-listener-bot.Dockerfile"
            DefaultTag  = "g4-file-listener-bot:latest"
            Name        = "File Listener Bot"
        },
        [ordered]@{
            Dockerfile  = "docker/g4-http-post-listener-bot.Dockerfile"
            DefaultTag  = "g4-http-post-listener-bot:latest"
            Name        = "HTTP Post Listener Bot"
        },
        [ordered]@{
            Dockerfile  = "docker/g4-http-qs-listener-bot.Dockerfile"
            DefaultTag  = "g4-http-qs-listener-bot:latest"
            Name        = "HTTP Query String Listener Bot"
        },
        [ordered]@{
            Dockerfile  = "docker/g4-http-static-listener-bot.Dockerfile"
            DefaultTag  = "g4-http-static-listener-bot:latest"
            Name        = "HTTP Static Listener Bot"
        },
        [ordered]@{
            Dockerfile  = "docker/g4-static-bot.Dockerfile"
            DefaultTag  = "g4-static-bot:latest"
            Name        = "Static Bot"
        }
    )

    # Begin an infinite loop to display the menu until the user chooses to go back.
    while ($true) {
        # Clear the console for a fresh view.
        Clear-Host

        # Display header message.
        Show-Logo -Title "Build G4-Bot Docker Image"

        # Iterate through dockerOptions to display each option with a numeric index.
        for ($i = 0; $i -lt $dockerOptions.Length; $i++) {
            Write-Host "$($i + 1)) $($dockerOptions[$i].Name)"
        }
        # Option to go back.
        Write-Host "0) Go Back"
        Write-Host ""

        # Prompt the user to enter their choice.
        $choice = Read-Host "Enter your choice"
       
        # Check if the user wants to exit the menu.
        if ($choice -eq "0") {
            break
        }
        # Validate that the choice is an integer and within the valid range.
        elseif ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $dockerOptions.Length) {
            # Retrieve the selected Docker option based on user input.
            $selectedOption = $dockerOptions[$choice - 1]
            
            # Define wizard parameters for the image tag.
            $wizardParam = @(
                @{
                    Default     = $selectedOption.DefaultTag
                    Description = "Optional image tag for the Docker image"
                    Mandatory   = $false
                    Name        = "ImageTag"
                    Type        = "String"
                }
            )
            
            # Invoke the wizard to build the Docker image, passing the Dockerfile path as an extra parameter.
            Show-Wizard `
                -Title            "Build Docker Image for $($selectedOption.Name)" `
                -WizardParameters $wizardParam `
                -ScriptToRun      "./New-G4BotImage.ps1" `
                -ExtraParams      @{ DockerfilePath = $selectedOption.Dockerfile }
        }
        else {
            # Prompt the user to press any key to return to the previous menu
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Write-Host "Press any key to return to the previous menu..."
            Read-Host
        }
    }
}

function Show-LaunchEnvironmentSubmenu {
    <#
    .SYNOPSIS
        Displays a submenu for launching various environment services.

    .DESCRIPTION
        This function presents a list of available environment launch options such as starting the Grid,
        Grid Hub, UIA Node, Browsers Node, G4 Hub, and Standalone UIA Driver Server. It prompts the user
        to select one of the options. Based on the selection, the corresponding wizard or launch function is
        invoked using the associated script.

    .OUTPUTS
        None. The function interacts with the user via the console and calls external scripts/functions.
    #>

    # Define environment launch options as an array of hashtables.
    # Each option contains a Name and the associated Script to run.
    $envOptions = @(
        @{ Name = "Start Grid";                         Script = "./grid/Start-Grid.ps1" },
        @{ Name = "Start Grid Hub";                     Script = "./grid/Start-SeleniumHub.ps1" },
        @{ Name = "Start UIA Node";                     Script = "./grid/Start-UiaNode.ps1" },
        @{ Name = "Start Chrome Node";                  Script = "./grid/Start-ChromeNode.ps1" },
        @{ Name = "Start Edge Node";                    Script = "./grid/Start-EdgeNode.ps1" },
        @{ Name = "Start G4 Hub";                       Script = "./Start-G4Hub.ps1" },
        @{ Name = "Start Standalone UIA Driver Server"; Script = "./grid/Start-UiaStandalone.ps1" }
    )

    # Begin an infinite loop to display the submenu until the user chooses to go back.
    while ($true) {
        # Clear the console for a fresh view.
        Clear-Host

        # Display the logo with a custom title for the environment submenu.
        Show-Logo -Title "Launch Environment Services"

        # Display each environment option with an associated number.
        for ($i = 0; $i -lt $envOptions.Length; $i++) {
            Write-Host "$($i + 1)) $($envOptions[$i].Name)"
        }
        # Always provide an option to go back.
        Write-Host "0) Go Back"
        Write-Host ""

        # Prompt the user to enter their choice.
        $choice = Read-Host "Enter your choice"

        # If the user enters "0", exit the submenu.
        if ($choice -eq "0") {
            break
        }
        # Validate that the input is an integer and within the range of available options.
        elseif ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $envOptions.Length) {
            # Retrieve the selected option.
            $selectedOption = $envOptions[$choice - 1]

            # Use a switch statement to determine which environment launch function to call.
            switch ($selectedOption.Name) {
                "Start Grid" {
                    Start-GridWizard -Script $selectedOption.Script
                }
                "Start Grid Hub" {
                    Start-GridHubWizard -Script $selectedOption.Script
                }
                "Start UIA Node" {
                    Start-UiaNodeWizard -Script $selectedOption.Script
                }
                "Start Chrome Node" {
                    Start-ChromeNodeWizard -Script $selectedOption.Script
                }
                "Start Edge Node" {
                    Start-EdgeNodeWizard -Script $selectedOption.Script
                }
                "Start G4 Hub" {
                    Start-G4HubWizard -Script $selectedOption.Script
                }
                "Start Standalone UIA Driver Server" {
                    Start-StandaloneUiaDriverServerWizard -Script $selectedOption.Script
                }
                default {
                    # Do nothing
                }
            }
        }
        else {
            # Prompt the user to press any key to return to the previous menu
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Write-Host "Press any key to return to the previous menu..."
            Read-Host
        }
    }
}

function Show-LaunchBotSubmenu {
    <#
    .SYNOPSIS
        Displays a submenu for launching different types of G4-Bots.

    .DESCRIPTION
        This function presents a list of available G4-Bot launch options and prompts the user to select one.
        Based on the user's choice, it calls the corresponding wizard function to start the bot.
        Options include Cron Bot, File Listener Bot, HTTP Post/Query String/Static Listener Bots, and Static Bot.
        If a bot type is not implemented, the user is notified accordingly.
    
    .OUTPUTS
        None. This function interacts with the user via the console and calls other functions to launch the bots.
    #>

    # Define an array of launch options (each option is a hashtable with Name and Script keys)
    $launchOptions = @(
        @{ Name = "Cron Bot";                       Script = "./Start-CronBot.ps1" },
        @{ Name = "File Listener Bot";              Script = "./Start-FileListenerBot.ps1" },
        @{ Name = "HTTP Post Listener Bot";         Script = "./Start-HttpPostListenerBot.ps1" },
        @{ Name = "HTTP Query String Listener Bot"; Script = "./Start-HttpQsListenerBot.ps1" },
        @{ Name = "HTTP Static Listener Bot";       Script = "./Start-HttpStaticListenerBot.ps1" },
        @{ Name = "Static Bot";                     Script = "./Start-StaticBot.ps1" }
    )

    # Begin a continuous loop until the user chooses to go back.
    while ($true) {
        # Clear the screen for a fresh menu display.
        Clear-Host

        # Display a header for the submenu.
        Show-Logo -Title "Launch a New G4-Bot"

        # Loop through each launch option and display its index and name.
        for ($i = 0; $i -lt $launchOptions.Length; $i++) {
            Write-Host "$($i + 1)) $($launchOptions[$i].Name)"
        }
        # Display option to go back.
        Write-Host "0) Go Back"
        Write-Host ""

        # Prompt the user to enter a choice.
        $choice = Read-Host "Enter your choice"
       
        # If the user chooses "0", exit the loop (go back).
        if ($choice -eq "0") {
            break
        }
        # Validate that the choice is a number within the valid range.
        elseif ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $launchOptions.Length) {
            # Retrieve the selected option based on the user's input.
            $selectedOption = $launchOptions[$choice - 1]
            
            # Use a switch statement to determine which wizard to start based on the selected option's name.
            switch ($selectedOption.Name) {
                "Cron Bot" {
                    Start-CronBotWizard -Script $selectedOption.Script
                }
                "File Listener Bot" {
                    Start-FileListenerBotWizard -Script $selectedOption.Script
                }
                # Merge cases for HTTP listener bots.
                { $_ -eq "HTTP Post Listener Bot" -or $_ -eq "HTTP Query String Listener Bot" -or $_ -eq "HTTP Static Listener Bot" } {
                    Start-HttpListenerBotWizard -Script $selectedOption.Script -Title "Launch $($selectedOption.Name)"
                }
                "Static Bot" {
                    Start-StaticBotWizard -Script $selectedOption.Script
                }
                default {
                    Write-Host "Launching for $($selectedOption.Name) is not implemented yet." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    Read-Host "Press Enter to continue..."
                }
            }
        }
        else {
            # Prompt the user to press any key to return to the previous menu
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Write-Host "Press any key to return to the previous menu..."
            Read-Host
        }
    }
}

function Show-UpdateDriverSubmenu {
    <#
    .SYNOPSIS
        Displays a submenu for updating drivers.

    .DESCRIPTION
        This function presents a list of driver update options:
          - Update Chrome Driver
          - Update Edge Driver
          - Update UIA Driver
        Based on the user's selection, the corresponding update script is executed.
        An option to go back is provided to return to the previous menu.

    .OUTPUTS
        None. This function interacts with the user via the console and executes external scripts.
    #>

    # Define update options as an array of hashtables.
    # Each option contains a Name and the corresponding Script to run.
    $updateOptions = @(
        @{ Name = "Update Chrome Driver"; Script = "./Update-ChromeDriver.ps1" },
        @{ Name = "Update Edge Driver";   Script = "./Update-EdgeDriver.ps1" },
        @{ Name = "Update UIA Driver";    Script = "./Update-UiaDriver.ps1" }
    )

    # Determine shell type.
    $shell = Resolve-Shell

    # Begin an infinite loop to display the submenu until the user chooses to go back.
    while ($true) {
        # Clear the console for a fresh view.
        Clear-Host

        # Display the logo with a custom title for the update drivers submenu.
        Show-Logo -Title "Update Drivers"

        # Loop through each update option and display it with an associated number.
        for ($i = 0; $i -lt $updateOptions.Length; $i++) {
            Write-Host "$($i + 1)) $($updateOptions[$i].Name)"
        }
        # Provide an option to go back.
        Write-Host "0) Go Back"
        Write-Host ""

        # Prompt the user to enter their choice.
        $choice = Read-Host "Enter your choice"

        # If the user chooses "0", exit the submenu.
        if ($choice -eq "0") {
            break
        }
        # Validate that the choice is an integer and within the valid range.
        elseif ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $updateOptions.Length) {
            # Retrieve the selected option.
            $selectedOption = $updateOptions[$choice - 1]

            # Execute the corresponding update script.
            try {
                # Start the process using the determined shell.
                $process = Start-Process -FilePath $shell -ArgumentList $selectedOption.Script -PassThru
            }
            catch {
                Write-Host "Error executing script $($selectedOption.Script): $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
                Read-Host
            }
        }
        else {
            # Inform the user if the input is invalid.
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Read-Host
        }
    }
}

function Show-UtilitiesSubmenu {
    <#
    .SYNOPSIS
        Displays a utilities submenu that offers options to convert strings to and from Base64.

    .DESCRIPTION
        This function creates an interactive submenu that presents a list of utility operations.
        Currently, it supports converting a string to Base64 and converting a Base64 string back to text.
        The submenu runs in an infinite loop until the user selects "Go Back".
        For each operation that requires input, the user is prompted to enter the appropriate data.
        The selected utility operation is then executed, and the result is displayed on the console.

    .EXAMPLE
        Show-UtilitiesSubmenu
        # Displays the utilities submenu and allows the user to choose an operation.
    #>

    # Define a scriptblock to convert an input string to Base64.
    $convertToBase64 = {
        param(
            [string]$InputString
        )
        # Convert the input string to a UTF-8 encoded byte array.
        $bytes  = [System.Text.Encoding]::UTF8.GetBytes($InputString)

        # Convert the byte array to a Base64 string.
        $output = [System.Convert]::ToBase64String($bytes)

        # Write the Base64 string to the host.
        Write-Host
        Write-Host "--- START ---"
        Write-Host $output
        Write-Host "--- END   ---"
    }

    # Define a scriptblock to convert a Base64 string back to a regular string.
    $convertFromBase64 = {
        param(
            [string]$InputBase64String
        )
        # Convert the Base64 string to a byte array.
        $bytes  = [System.Convert]::FromBase64String($InputBase64String)

        # Decode the byte array using UTF-8 encoding to obtain the original string.
        $output = [System.Text.Encoding]::UTF8.GetString($bytes)

        # Write the decoded string to the host.
        Write-Host
        Write-Host "--- START ---"
        Write-Host $output
        Write-Host "--- END   ---"
    }

    # Converts a Unix timestamp (in seconds) to a UTC DateTime.
    $convertFromUnixTimeSeconds = {
        # Define the function parameter for the Unix timestamp.
        param(
            $timestamp  # Unix time in seconds since January 1, 1970
        )
    
        # Output a blank line for visual separation.
        Write-Host

        # Convert the Unix timestamp to a DateTimeOffset,
        # then extract and display the corresponding UTC DateTime.
        Write-Host ([DateTimeOffset]::FromUnixTimeSeconds($timestamp).UtcDateTime.ToString("o"))
    }

    # Reads multi-line input from the console until a specified terminator is entered.
    $getMultilineInput = {
        # Define the parameter for the terminator with a default value of 'EOF'
        param(
            [string]$Terminator = 'EOF'
        )
    
        # Inform the user how to input the text and the terminator instruction
        Write-Host "Paste or type your text. When finished, type '$Terminator' on a new line."
    
        # Initialize an empty string to accumulate the multi-line input
        $text = ""
    
        # Loop to continuously read input until the terminator is entered
        while (($line = Read-Host) -ne $Terminator) {
            # Append the entered line followed by a newline character to the accumulated text
            $text += $line + "`n"
        }

        # Return the complete multi-line text collected from the user
        return $text
    }

    # Define a scriptblock to generates a random alphanumeric string.
    $newRandomString = {
        # Set the character set.
        $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        # Generate a random length between 15 and 55 (Get-Random's -Maximum is exclusive, so use 56).
        $length = Get-Random -Minimum 15 -Maximum 56

        # Build the random string by selecting a random character from the set for each position.
        $randomString = -join (1..$length | ForEach-Object {
            # Select a random index in the character set.
            $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)]
        })

        # Output the generated random string.
        Write-Host
        Write-Host $randomString
    }

    # Create an array of utility options. Each option is a hashtable containing:
    #   - Name    : The label to display.
    #   - Script  : The scriptblock to execute.
    #   - Title   : A prompt for input if required.
    #   - HasInput: A flag indicating if the option requires user input.
    $utilitiesOptions = @(
        @{
            Name    = "Convert String To Base64"
            Script  = $convertToBase64
            Title   = "Enter the text to encode into Base64:"
            HasInput= $true
        },
        @{
            Name    = "Convert String To Base64 - Multiline"
            Script  = $convertToBase64
            Title   = "Enter the text to encode into Base64:"
            HasInput= $true
        },
        @{
            Name    = "Convert String From Base64"
            Script  = $convertFromBase64
            Title   = "Enter the Base64 encoded text to decode:"
            HasInput= $true
        },
        @{
            Name    = "New Random Alphanumeric String"
            Script  = $newRandomString
            Title   = ""
            HasInput= $false
        },
        @{
            Name    = "Get Unix Time Seconds (UTC)"
            Script  = { Write-Host "$([System.Environment]::NewLine)$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" }
            Title   = ""
            HasInput= $false
        },
        @{
            Name    = "Convert From Unix Time Seconds To UTC"
            Script  = $convertFromUnixTimeSeconds
            Title   = "Enter the Unix timestamp (in seconds since epoch) to convert to UTC:"
            HasInput= $true
        }
    )

    # Determine the appropriate shell to use based on the operating system.
    $shell = Resolve-Shell

    # Begin an infinite loop to display the submenu until the user chooses to go back.
    while ($true) {
        # Clear the console to refresh the display.
        Clear-Host

        # Display the submenu logo and title.
        Show-Logo -Title "Utilities"

        # Loop through each utility option and display it with a numbered index.
        for ($i = 0; $i -lt $utilitiesOptions.Length; $i++) {
            Write-Host "$($i + 1)) $($utilitiesOptions[$i].Name)"
        }

        # Display an option for the user to go back to the previous menu.
        Write-Host "0) Go Back"
        Write-Host ""

        # Prompt the user to enter their choice.
        $choice = Read-Host "Enter your choice"

        # Exit the submenu if the user chooses "0".
        if ($choice -eq "0") {
            break
        }

        # Validate that the choice is a valid integer within the range of options.
        elseif ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $utilitiesOptions.Length) {
            # Retrieve the selected option based on the user's choice.
            $selectedOption = $utilitiesOptions[$choice - 1]

            try {
                # Evaluate the selected option's name with a switch statement.
                switch ($selectedOption.Name) {
                    "Convert String To Base64 - Multiline" {
                        # Display the title of the selected option.
                        Write-Host $selectedOption.Title

                        # Invoke the function to get multi-line input.
                        $content = & $getMultilineInput
            
                        # Execute the script associated with the selected option, passing in the content.
                        & $selectedOption.Script $content

                        break
                    }
                    { $_ -eq "Convert String To Base64" -or $_ -eq "Convert String From Base64" -or $_ -eq "Convert From Unix Time Seconds To UTC" } {
                        # Display the title of the selected option.
                        Write-Host $selectedOption.Title

                        # Read a single line input from the user.
                        $content = Read-Host

                        # Execute the script associated with the selected option, passing in the content.
                        & $selectedOption.Script $content

                        break
                    }
                    { $_ -eq "New Random Alphanumeric String" -or $_ -eq "Get Unix Time Seconds (UTC)" } {
                        # Execute the script associated with the selected option.
                        & $selectedOption.Script

                        break
                    }
                    # Default case when no matching option is found.
                    default {
                        Write-Host "No matching case found for '$string'"
                    }
                }

                Write-Host
                Write-Host "Press any key to return to the previous menu..."
                Read-Host
            }
            catch {
                # Display any error encountered during script execution.
                Write-Host "Error executing script $($selectedOption.Script): $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
                Read-Host
            }
        }
        else {
            # Inform the user if an invalid choice was made.
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Read-Host
        }
    }
}

function Start-ChromeNodeWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for starting a Chrome Node.

    .DESCRIPTION
        This function sets up a wizard to collect the necessary configuration for starting a Chrome Node.
        It collects two parameters:
          - GridHubUri: The drivers endpoint for the Grid. Defaults to "http://localhost:4444/wd/hub".
          - NodePort: The port for the Chrome Node. Defaults to 5552.
        Both parameters are not mandatory; if no input is provided, their respective default values are used.
        Once the parameters are collected, the specified script is executed with the provided configuration.

    .PARAMETER Script
        The path to the script that will be executed after collecting the Chrome Node configuration.

    .EXAMPLE
        Start-ChromeNodeWizard -Script "./Start-ChromeNode.ps1"
        # Launches the wizard to collect parameters and then runs the Start-ChromeNode.ps1 script.
    #>
    param(
        [string]$Script
    )

    # Define wizard parameters for starting the Chrome Node.
    $wizardParameters = @(
        [ordered]@{
            Default          = "http://localhost:4444/wd/hub"
            Description      = "Enter the Grid Hub URI (drivers endpoint) for the Chrome Node."
            EnvironmentValue = $env:DRIVER_BINARIES
            Mandatory        = $true
            Name             = "GridHubUri"
            Type             = "String"
        },
        [ordered]@{
            Default          = 5552
            Description      = "Enter the port for the Chrome Node."
            EnvironmentValue = $env:CHROME_NODE_PORT
            Mandatory        = $true
            Name             = "NodePort"
            Type             = "Number"
        }
    )

    # Invoke the wizard interface to collect the Chrome Node parameters
    # and then execute the provided script with the collected configuration.
    Show-Wizard `
        -Title            "Launch Chrome Node" `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-CronBotWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for configuring and starting a Cron Bot.

    .DESCRIPTION
        This function builds a set of ordered wizard parameters required to configure the Cron Bot.
        It then calls the Show-Wizard function to display a wizard interface to the user.
        The wizard collects values for each parameter, which are then used by the provided script
        to launch the Cron Bot.

    .PARAMETER Script
        The path to the script that will be executed after the wizard configuration is complete.

    .OUTPUTS
        None. The function calls Show-Wizard which handles user input and execution.
    #>
    param(
        $Script
    )

    # Define the wizard parameters as an array of ordered hashtables.
    # Each parameter is configured with a default value, description, whether it's mandatory, and its name.
    $wizardParameters = @(
        [ordered]@{
            Default          = ""
            Description      = "The root directory where the bot operates."
            EnvironmentValue = $env:BOT_VOLUME
            Mandatory        = $true
            Name             = "BotVolume"
            Type             = "String"
        },
        [ordered]@{
            Default          = "g4-cron-bot"
            Description      = "The name of the bot, used for identification and folder naming."
            EnvironmentValue = $env:CRON_BOT_NAME
            Mandatory        = $true
            Name             = "BotName"
            Type             = "String"
        },
        [ordered]@{
            Default          = "* * * * *"
            Description      = "A comma-separated list of cron expressions (e.g., '0 0 * * *') used to schedule tasks."
            EnvironmentValue = $env:CRON_BOT_SCHEDULES
            Mandatory        = $true
            Name             = "CronSchedules"
            Type             = "String"
        },
        [ordered]@{
            Default          = "http://localhost:4444/wd/hub"
            Description      = "The directory containing the driver binaries or the grid endpoint for drivers."
            EnvironmentValue = $env:DRIVER_BINARIES
            Mandatory        = $true
            Name             = "DriverBinaries"
            Type             = "String"
        },
        [ordered]@{
            Default          = "http://localhost:9944"
            Description      = "The base URI of the G4 Hub endpoint to which automation configurations are sent."
            EnvironmentValue = $env:G4_HUB_URI
            Mandatory        = $true
            Name             = "HubUri"
            Type             = "String"
        },
        [ordered]@{
            Default          = ""
            Description      = "The authentication token (G4 license token) required for accessing the G4 Hub."
            EnvironmentValue = $env:G4_LICENSE_TOKEN
            Mandatory        = $true
            Name             = "Token"
            Type             = "String"
        },
        [ordered]@{
            Default          = $false
            Description      = "Indicates whether to run using the latest Docker image (enter 'Y' for yes; default is no)."
            EnvironmentValue = ""
            Mandatory        = $false
            Name             = "Docker"
            Type             = "Switch"
        }
    )

    # Call the Show-Wizard function with the defined parameters.
    Show-Wizard `
        -Title            "Launch Cron Bot" `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-FileListenerBotWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for configuring and starting a File Listener Bot.

    .DESCRIPTION
        This function sets up the required wizard parameters for the File Listener Bot. It defines a set of
        ordered parameters such as the bot's volume, name, driver binaries location, hub URI, polling interval,
        authentication token, and whether to use Docker. It then invokes the Show-Wizard function, which displays
        a user interface to collect values for these parameters and executes the provided script to launch the bot.

    .PARAMETER Script
        The path to the script that will be executed after the wizard configuration is complete.

    .OUTPUTS
        None. The function displays a wizard to the user and passes the collected parameters to the specified script.
    #>
    param(
        $Script
    )

    # Define wizard parameters as an array of ordered hashtables. Each ordered hashtable ensures that
    # the keys (Default, Description, Mandatory, Name) appear in a consistent order.
    $wizardParameters = @(
        [ordered]@{
            Default          = ""
            Description      = "The root directory where the bot will operate."
            EnvironmentValue = $env:BOT_VOLUME
            Mandatory        = $true
            Name             = "BotVolume"
            Type             = "String"
        },
        [ordered]@{
            Default          = "g4-file-listener-bot"
            Description      = "The name of the bot, used for identification and folder naming."
            EnvironmentValue = $env:FILE_LISTENER_BOT_NAME
            Mandatory        = $true
            Name             = "BotName"
            Type             = "String"
        },
        [ordered]@{
            Default          = "http://localhost:4444/wd/hub"
            Description      = "The directory containing the driver binaries or the grid endpoint for drivers."
            EnvironmentValue = $env:DRIVER_BINARIES
            Mandatory        = $true
            Name             = "DriverBinaries"
            Type             = "String"
        },
        [ordered]@{
            Default          = ""
            Description      = "The base URI of the G4 Hub endpoint to which automation configurations are sent."
            EnvironmentValue = $env:G4_HUB_URI
            Mandatory        = $true
            Name             = "HubUri"
            Type             = "String"
        },
        [ordered]@{
            Default          = 10
            Description      = "The polling interval (in seconds) between each file check."
            EnvironmentValue = $env:FILE_LISTENER_BOT_INTERVAL_TIME
            Mandatory        = $true
            Name             = "IntervalTime"
            Type             = "Number"
        },
        [ordered]@{
            Default          = ""
            Description      = "The authentication token (G4 license token) required for accessing the G4 Hub."
            EnvironmentValue = $env:G4_LICENSE_TOKEN
            Mandatory        = $true
            Name             = "Token"
            Type             = "String"
        },
        [ordered]@{
            Default          = $false
            Description      = "Indicates whether to run using the latest Docker image (enter 'Y' for yes; default is no)."
            EnvironmentValue = ""
            Mandatory        = $false
            Name             = "Docker"
            Type             = "Switch"
        }
    )

    # Invoke the wizard to launch the File Listener Bot.
    Show-Wizard `
        -Title            "Launch File Listener Bot" `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-G4HubWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for starting the G4 Hub.

    .DESCRIPTION
        This function is used to launch the G4 Hub. Unlike other wizards,
        it does not collect any parameters from the user. It simply invokes
        the specified script to start the G4 Hub.

    .PARAMETER Script
        The path to the script that will be executed to launch the G4 Hub.

    .EXAMPLE
        Start-G4HubWizard -Script "./Start-G4Hub.ps1"
        # Launches the G4 Hub by executing the specified script.
    #>
    param(
        [string]$Script
    )

    # Inform the user that the G4 Hub is being launched.
    Write-Host "Launching G4 Hub..." -ForegroundColor Cyan

    # Determine shell type.
    $shell = Resolve-Shell

    # Try to execute the provided script.
    try {
        $process = Start-Process -FilePath $shell -ArgumentList $Script -PassThru
    }
    catch {
        Write-Error "Error launching G4 Hub: $($_.Exception.GetBaseException())"
    }

    # Prompt the user to press any key to return to the previous menu.
    Write-Host ""
    Write-Host "Press any key to return to the previous menu..."
    Read-Host
}

function Start-GridHubWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for starting the Grid Hub.

    .DESCRIPTION
        This function sets up a wizard to collect the necessary configuration for starting the Grid Hub.
        It collects the SessionRequestTimeout parameter, which represents the timeout for session requests.
        The parameter is not mandatory; if no input is provided, it defaults to 42300.
        Once the parameter is collected, the specified script is executed with the provided configuration.

    .PARAMETER Script
        The path to the script that will be executed after collecting the Grid Hub configuration.

    .EXAMPLE
        Start-GridHubWizard -Script "./Start-GridHub.ps1"
        # Launches the wizard to collect the SessionRequestTimeout and then runs the Start-GridHub.ps1 script.
    #>
    param(
        [string]$Script
    )

    # Define wizard parameters for starting the Grid Hub.
    # SessionRequestTimeout is not mandatory and defaults to 42300.
    $wizardParameters = @(
        [ordered]@{
            Default          = "42300"
            Description      = "Enter the session request timeout value."
            EnvironmentValue = $env:SESSION_REQUEST_TIMEOUT
            Mandatory        = $false
            Name             = "SessionRequestTimeout"
            Type             = "Number"
        }
    )

    # Invoke the wizard interface to collect the SessionRequestTimeout parameter
    # and then execute the provided script with the collected parameters.
    Show-Wizard `
        -Title            "Launch Grid Hub" `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-EdgeNodeWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for starting an Edge Node.

    .DESCRIPTION
        This function sets up a wizard to collect the necessary configuration for starting an Edge Node.
        It collects two parameters:
          - GridHubUri: The drivers endpoint for the Grid. Defaults to "http://localhost:4444/wd/hub".
          - NodePort: The port for the Edge Node. Defaults to 5553.
        Both parameters are not mandatory; if no input is provided, their respective default values are used.
        Once the parameters are collected, the specified script is executed with the provided configuration.

    .PARAMETER Script
        The path to the script that will be executed after collecting the Edge Node configuration.

    .EXAMPLE
        Start-EdgeNodeWizard -Script "./Start-EdgeNode.ps1"
        # Launches the wizard to collect parameters and then runs the Start-EdgeNode.ps1 script.
    #>
    param(
        [string]$Script
    )

    # Define wizard parameters for starting the Edge Node.
    $wizardParameters = @(
        [ordered]@{
            Default          = "http://localhost:4444/wd/hub"
            Description      = "Enter the Grid Hub URI (drivers endpoint) for the Edge Node."
            EnvironmentValue = $env:DRIVER_BINARIES
            Mandatory        = $true
            Name             = "GridHubUri"
            Type             = "String"
        },
        [ordered]@{
            Default          = 5553
            Description      = "Enter the port for the Edge Node."
            EnvironmentValue = $env:EDGE_NODE_PORT
            Mandatory        = $true
            Name             = "NodePort"
            Type             = "Number"
        }
    )

    # Invoke the wizard interface to collect the Edge Node parameters
    # and then execute the provided script with the collected configuration.
    Show-Wizard `
        -Title            "Launch Edge Node" `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-GridWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for starting the Grid.

    .DESCRIPTION
        This function sets up a wizard to collect the necessary configuration for starting the Grid.
        It collects the GridHubUri parameter, which represents the drivers endpoint for the Grid.
        The parameter is not mandatory; if no input is provided, it defaults to "http://localhost:4444/wd/hub".
        Once the parameter is collected, the specified script is executed with the provided configuration.

    .PARAMETER Script
        The path to the script that will be executed after collecting the Grid configuration.

    .EXAMPLE
        Start-GridWizard -Script "./Start-Grid.ps1"
        # Launches the wizard to collect the GridHubUri and then runs the Start-Grid.ps1 script.
    #>
    param(
        [string]$Script
    )

    # Define wizard parameters for starting the Grid.
    # GridHubUri is not mandatory and defaults to "http://localhost:4444/wd/hub".
    $wizardParameters = @(
        [ordered]@{
            Default          = "http://localhost:4444/wd/hub"
            Description      = "Enter the Grid Hub URI (drivers endpoint) for the Grid."
            EnvironmentValue = $env:DRIVER_BINARIES
            Mandatory        = $true
            Name             = "GridHubUri"
            Type             = "String"
        }
    )

    # Invoke the wizard interface to collect the GridHubUri parameter
    # and then execute the provided script with the collected parameters.
    Show-Wizard `
        -Title            "Launch Grid" `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-HttpListenerBotWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for configuring and starting an HTTP Listener Bot.

    .DESCRIPTION
        This function sets up the required wizard parameters for the HTTP Listener Bot. It creates a list of
        ordered parameters including the bot's volume, name, HTTP port, content type, driver binaries location,
        hub URI, default response content, authentication token, and Docker usage option. The function then
        calls the Show-Wizard function to display a user-friendly interface for collecting these parameters,
        after which the provided script is executed with the collected configuration.

    .PARAMETER Script
        The path to the script that will be executed after the wizard configuration is complete.

    .OUTPUTS
        None. The function invokes Show-Wizard which handles user input and subsequent execution.
    #>
    param(
        $Title,
        $Script
    )

    # Define wizard parameters as an array of ordered hashtables.
    # Each ordered hashtable ensures that keys appear in the following order: Default, Description, Mandatory, Name.
    $wizardParameters = @(
        [ordered]@{
            Default          = ""
            Description      = "The root directory where the bot will operate."
            EnvironmentValue = $env:BOT_VOLUME
            Mandatory        = $true
            Name             = "BotVolume"
            Type             = "String"
        },
        [ordered]@{
            Default          = "g4-http-listener-bot"
            Description      = "The name of the bot."
            EnvironmentValue = $env:HTTP_LISTENER_BOT_NAME
            Mandatory        = $true
            Name             = "BotName"
            Type             = "String"
        },
        [ordered]@{
            Default          = 8080
            Description      = "The port on which the HTTP POST listener will run."
            EnvironmentValue = $env:HOST_PORT
            Mandatory        = $false
            Name             = "HostPort"
            Type             = "Number"
        },
        [ordered]@{
            Default          = "application/json; charset=utf-8"
            Description      = "The HTTP Content-Type header value."
            EnvironmentValue = $env:CONTENT_TYPE
            Mandatory        = $false
            Name             = "ContentType"
            Type             = "String"
        },
        [ordered]@{
            Default          = "http://localhost:4444/wd/hub"
            Description      = "The directory where the drivers are located or the grid endpoint."
            EnvironmentValue = $env:DRIVER_BINARIES
            Mandatory        = $true
            Name             = "DriverBinaries"
            Type             = "String"
        },
        [ordered]@{
            Default          = "http://localhost:9944"
            Description      = "The base URI of the G4 Hub endpoint to which automation configurations are sent."
            EnvironmentValue = $env:G4_HUB_URI
            Mandatory        = $true
            Name             = "HubUri"
            Type             = "String"
        },
        [ordered]@{
            Default          = 'eyJtZXNzYWdlIjogInN1Y2Nlc3MifQ=='
            Description      = "The default HTTP response content (e.g., 'eyJtZXNzYWdlIjogInN1Y2Nlc3MifQ==')."
            EnvironmentValue = $env:BASE64_RESPONSE_CONTENT
            Mandatory        = $false
            Name             = "Base64ResponseContent"
            Type             = "String"
        },
        [ordered]@{
            Default          = ""
            Description      = "The authentication token (G4 License token) required to access the G4 Hub."
            EnvironmentValue = $env:G4_LICENSE_TOKEN
            Mandatory        = $true
            Name             = "Token"
            Type             = "String"
        },
        [ordered]@{
            Default          = $false
            Description      = "Indicates whether to run using the latest Docker image (enter 'Y' for yes; default is no)."
            EnvironmentValue = $null
            Mandatory        = $false
            Name             = "Docker"
            Type             = "Switch"
        }
    )

    # Invoke the wizard interface to collect parameters and launch the HTTP Listener Bot.
    Show-Wizard `
        -Title            $Title `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-NewPartitionWizard {
    <#
    .SYNOPSIS
        Initializes a new G4-Bot partition wizard.
    
    .DESCRIPTION
        This function sets up the environment for creating a new G4-Bot partition.
        It determines the appropriate bot volume based on the operating system,
        prepares wizard parameters, and then calls the Show-Wizard function to
        run the partition initialization script.

    .NOTES
        The function adapts the bot volume path for non-Windows systems.
        It also generates a unique bot partition name using the Unix epoch time.
    #>

    # Set the default bot volume path for Windows systems
    $botVolume = "C:\g4-bots-volume"
    
    # Check if the operating system is not Windows (i.e., not Win32NT)
    # Set the bot volume path for non-Windows systems (e.g., Linux)
    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        $botVolume = "/srv/shared/g4-bots-volume"
    }

    # Define the wizard parameters as an array of hashtables.
    # Each hashtable represents a parameter with its default value, description, mandatory flag, and name.
    $WizardParameters = @(
        @{
            Default          = $botVolume
            Description      = "The root path where to create the bot partition"
            EnvironmentValue = $env:BOT_VOLUME
            Mandatory        = $true
            Name             = "BotVolume"
            Type             = "String"
        },
        @{
            # Generate a unique bot partition name using Unix epoch time for uniqueness
            Default          = "g4-bot-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
            Description      = "The bot partition (folder) name"
            EnvironmentValue = $null
            Mandatory        = $true
            Name             = "BotName"
            Type             = "String"
        }
    )

    # Call the Show-Wizard function to display the wizard interface.
    # It uses the provided title, parameters, and the script that will run once the wizard completes.
    Show-Wizard `
        -Title            "Initialize a New G4-Bot Partition Wizard" `
        -WizardParameters $WizardParameters `
        -ScriptToRun      "./Initialize-G4BotPartition.ps1"
}

function Start-StaticBotWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for configuring and starting a Static Bot.

    .DESCRIPTION
        This function sets up the required wizard parameters for the Static Bot.
        It defines a set of ordered parameters including the bot's operating volume, name,
        driver binaries location, hub URI, polling interval, authentication token, and Docker usage.
        After setting up these parameters, it calls the Show-Wizard function to present a user-friendly
        interface for collecting configuration values and then executes the provided script using these values.

    .PARAMETER Script
        The path to the script that will be executed after the wizard configuration is complete.

    .OUTPUTS
        None. The function calls Show-Wizard which handles user input and the subsequent bot launch.
    #>
    param(
        $Script
    )

    # Define wizard parameters as an array of ordered hashtables.
    # Each ordered hashtable ensures that the keys appear in the specified order:
    # Default, Description, Mandatory, and Name.
    $wizardParameters = @(
        [ordered]@{
            Default          = ""
            Description      = "The root directory where the bot will operate."
            EnvironmentValue = $env:BOT_VOLUME
            Mandatory        = $true
            Name             = "BotVolume"
            Type             = "String"
        },
        [ordered]@{
            Default          = "g4-static-bot"
            Description      = "The name of the bot."
            EnvironmentValue = $env:STATIC_BOT_NAME
            Mandatory        = $true
            Name             = "BotName"
            Type             = "String"
        },
        [ordered]@{
            Default          = "http://localhost:4444/wd/hub"
            Description      = "The directory containing the drivers, or the grid endpoint."
            EnvironmentValue = $env:DRIVER_BINARIES
            Mandatory        = $true
            Name             = "DriverBinaries"
            Type             = "String"
        },
        [ordered]@{
            Default          = "http://localhost:9944"
            Description      = "The base URI of the G4 Hub endpoint to which automation configurations are sent."
            EnvironmentValue = $env:G4_HUB_URI
            Mandatory        = $true
            Name             = "HubUri"
            Type             = "String"
        },
        [ordered]@{
            Default          = 60
            Description      = "The interval (in seconds) between each bot call."
            EnvironmentValue = $env:STATIC_BOT_INTERVAL_TIME
            Mandatory        = $true
            Name             = "IntervalTime"
            Type             = "Number"
        },
        [ordered]@{
            Default          = ""
            Description      = "The authentication token (G4 License token) required for accessing the G4 Hub."
            EnvironmentValue = $env:G4_LICENSE_TOKEN
            Mandatory        = $true
            Name             = "Token"
            Type             = "String"
        },
        [ordered]@{
            Default          = $false
            Description      = "Indicates whether to run using the latest Docker image (enter 'Y' for yes; default is no)."
            EnvironmentValue = ""
            Mandatory        = $false
            Name             = "Docker"
            Type             = "Switch"
        }
    )

    # Call the Show-Wizard function with the specified title, wizard parameters, and script.
    Show-Wizard `
        -Title            "Launch Static Bot" `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-UiaNodeWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for starting a UIA Node.

    .DESCRIPTION
        This function sets up a wizard to collect the necessary configuration for starting a UIA Node.
        It collects two parameters:
          - GridHubUri: The drivers endpoint for the Grid. Defaults to "http://localhost:4444/wd/hub".
          - NodePort: The port for the UIA Node. Defaults to 5554.
        Both parameters are not mandatory. If no input is provided, their respective default values are used.
        Once the parameters are collected, the specified script is executed with the provided configuration.

    .PARAMETER Script
        The path to the script that will be executed after collecting the UIA Node configuration.

    .EXAMPLE
        Start-UiaNodeWizard -Script "./Start-UiaNode.ps1"
        # Launches the wizard to collect parameters and then runs the Start-UiaNode.ps1 script.
    #>
    param(
        [string]$Script
    )

    # Define wizard parameters for starting the UIA Node.
    $wizardParameters = @(
        [ordered]@{
            Default          = "http://localhost:4444/wd/hub"
            Description      = "Enter the Grid Hub URI (drivers endpoint) for the UIA Node."
            EnvironmentValue = $env:DRIVER_BINARIES
            Mandatory        = $false
            Name             = "GridHubUri"
            Type             = "String"
        },
        [ordered]@{
            Default          = 5554
            Description      = "Enter the port for the UIA Node."
            EnvironmentValue = $env:UIA_NODE_PORT
            Mandatory        = $false
            Name             = "NodePort"
            Type             = "Number"
        }
    )

    # Invoke the wizard interface to collect the UIA Node parameters
    # and then execute the provided script with the collected configuration.
    Show-Wizard `
        -Title            "Launch UIA Node" `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-StandaloneUiaDriverServerWizard {
    <#
    .SYNOPSIS
        Launches the wizard interface for starting the Standalone UIA Driver Server.

    .DESCRIPTION
        This function sets up a wizard to collect the necessary configuration for starting the Standalone UIA Driver Server.
        It collects one parameter:
          - ServicePort: The port on which the UIA Driver Server will run. Defaults to 5555.
        The parameter is not mandatory; if no input is provided, the default value is used.
        Once the parameter is collected, the specified script is executed with the provided configuration.

    .PARAMETER Script
        The path to the script that will be executed after collecting the configuration.

    .EXAMPLE
        Start-StandaloneUiaDriverServerWizard -Script "./Start-StandaloneUiaDriverServer.ps1"
        # Launches the wizard to collect the ServicePort and then runs the Start-StandaloneUiaDriverServer.ps1 script.
    #>
    param(
        [string]$Script
    )

    # Define wizard parameters for starting the Standalone UIA Driver Server.
    $wizardParameters = @(
        [ordered]@{
            Default          = 5555
            Description      = "Enter the port for the Standalone UIA Driver Server."
            EnvironmentValue = $env:UIA_DRIVER_PORT
            Mandatory        = $false
            Name             = "ServicePort"
            Type             = "Number"
        }
    )

    # Invoke the wizard interface to collect the ServicePort parameter
    # and then execute the provided script with the collected configuration.
    Show-Wizard `
        -Title            "Launch Standalone UIA Driver Server" `
        -WizardParameters $wizardParameters `
        -ScriptToRun      $Script
}

function Start-Main {
    <#
    .SYNOPSIS
        Displays the main menu and controls the overall program flow.

    .DESCRIPTION
        This function enters an infinite loop to display the main menu options and wait for user input.
        The main menu provides three options:
          1. Initialize a New G4-Bot Partition
          2. Build G4-Bot Docker Image
          3. Launch a New G4-Bot
        After displaying the menu, the function prompts the user to either exit by pressing 'Q' or return to the
        main menu by pressing any other key.

    .OUTPUTS
        None. The function handles user interaction and controls the program flow.
    #>
    
    # Begin an infinite loop to continuously display the main menu until the user chooses to exit.
    while ($true) {
        # Define the options for the main menu as an array of strings.
        $mainMenuOptions = @(
            "Initialize a New G4-Bot Partition",
            "Launch a New G4-Bot",
            "Launch Environment",
            "Build G4-Bot Docker Image",
            "Update Driver",
            "Utilities"
        )

        # Display the main menu using a helper function (assumed to be defined elsewhere).
        # The -Title parameter sets the menu title, and -Options provides the list of choices.
        Show-Menu -Title "Main Menu" -Options $mainMenuOptions

        # Display a blank line for better readability.
        Write-Host ""

        # Prompt the user to either quit or return to the main menu.
        # If the user presses 'Q' or 'q', the loop will break and the function will exit.
        $exit = Read-Host "Press Q to quit or any other key to return to the Main Menu"
        if ($exit -match '^[Qq]$') {
            break
        }
    }
}

# Start the application
Import-EnvironmentVariablesFile
Start-Main
