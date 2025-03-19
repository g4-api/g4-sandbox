<#
.SYNOPSIS
    Creates a structured set of directories and writes a default automation.json file.

.DESCRIPTION
    This script accepts two mandatory parameters: 
      - BotVolume: The base path or volume where the directories will be created.
      - BotName: The name of the bot, which is used to form a subdirectory under BotVolume.
      
    It then constructs a root directory from these parameters, creates the following subdirectories:
      .tmp, archive, bot, errors, input, output
      
    Finally, the script writes a predefined JSON configuration file (automation.json) to the 'bot' directory.
    
.PARAMETER BotVolume
    The base path or volume (e.g., "C:\Bots") where the folder structure will be created.

.PARAMETER BotName
    The name of the bot (e.g., "MyBot"), used as a subdirectory under BotVolume.

.EXAMPLE
    .\Initialize-BotPartition.ps1 -BotVolume "C:\Bots" -BotName "MyBot"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BotVolume,

    [Parameter(Mandatory=$true)]
    [string]$BotName
)

# Build the root directory path by joining BotVolume and BotName
# Example: if BotVolume is "C:\Bots" and BotName is "MyBot", the rootPath becomes "C:\Bots\MyBot"
$rootPath = Join-Path $BotVolume $BotName

# Create the root directory if it doesn't exist
if (!(Test-Path -Path $rootPath)) {
    New-Item -Path $rootPath -ItemType Directory -Force | Out-Null
}

# Define the directories to create under the root directory
$directories = @(".tmp", "archive", "bot", "errors", "input", "output")

# Loop through each directory name in the array and create it if it doesn't exist
foreach ($directory in $directories) {
    # Build the full path for the directory
    $directoryPath = Join-Path $rootPath $directory

    # Create the directory only if it is not already present
    if (!(Test-Path -Path $directoryPath)) {
        New-Item -Path $directoryPath -ItemType Directory -Force | Out-Null
    }
}

# Define the JSON content for automation.json using a here-string
# This JSON content includes default configuration values.
$jsonContent = @"
{
    "authentication": {
        "token": "",
        "password": "",
        "username": ""
    },
    "driverParameters": {
        "capabilities": {
            "alwaysMatch": {}
        },
        "driver": "MicrosoftEdgeDriver",
        "driverBinaries": ".",
        "firstMatch": [
            {}
        ]
    },
    "settings": {
        "automationSettings": {
            "loadTimeout": 60000,
            "maxParallel": 1,
            "returnStructuredResponse": false,
            "searchTimeout": 15000
        },
        "environmentSettings": {
            "defaultEnvironment": "SystemParameters",
            "returnEnvironment": false
        },
        "screenshotsSettings": {
            "outputdirectory": ".",
            "convertToBase64": false,
            "exceptionsOnly": false,
            "returnScreenshots": false
        },
        "pluginsSettings": {
            "externalRepositories": []
        }
    },
    "stages": [
        {
            "reference": {
                "name": "G4™ Default Stage"
            },
            "jobs": [
                {
                    "reference": {
                        "name": "G4™ Default Job"
                    },
                    "rules": [
                        {
                            "$type": "Action",
                            "pluginName": "WriteLog",
                            "capabilities": {
                                "displayName": "Write Log"
                            },
                            "argument": "Foo Bar"
                        }
                    ]
                }
            ]
        }
    ]
}
"@

# Define the path to the 'bot' directory under the root directory
$botDirectoryPath = Join-Path $rootPath "bot"

# Define the full path to the automation.json file within the 'bot' directory
$automationJsonPath = Join-Path $botDirectoryPath "automation.json"

# Write the JSON content to automation.json with UTF8 encoding
$jsonContent | Out-File -FilePath $automationJsonPath -Encoding UTF8

# Output a confirmation message to the console with the path of the created JSON file
Write-Host "Directories created and automation.json has been written to $automationJsonPath"