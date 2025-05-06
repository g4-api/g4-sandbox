# Change to the script's own directory so any relative paths resolve correctly
Set-Location -Path $PSScriptRoot

# Import the bot monitor and common utility modules
Import-Module './BotMonitor.psm1' -Force
Import-Module './BotCommon.psm1'  -Force

<#
.SYNOPSIS
    Initializes a bot by building its configuration, starting its callback listener, and launching a watchdog.

.DESCRIPTION
    Initialize-Bot constructs the bot’s runtime configuration (endpoints, metadata, and timeouts) via 
    New-BotConfiguration, then:
      1. Starts the bot’s HTTP callback listener in a background runspace using Start-BotCallbackListener.
      2. Launches a watchdog loop with Start-BotWatchDog to monitor and re-register the bot until the listener finishes.
    Returns a PSCustomObject containing the configuration and handles to both background jobs.

.PARAMETER BotName
    The human-readable name of the bot (e.g. "MyBot").

.PARAMETER BotType
    The category or type of the bot (e.g. "static-bot", "worker").

.PARAMETER BotVolume
    The path to the bot’s working volume or directory.

.PARAMETER CallbackPort
    (Optional) TCP port for the bot’s callback listener. If omitted, a free port will be chosen.

.PARAMETER EntryPointPort
    (Optional) TCP port for the bot’s main entry-point service. If omitted, a free port will be chosen.

.PARAMETER EnvironmentFilePath
    Path to the environment file (e.g. ".env") containing KEY=VALUE pairs to load before startup.

.PARAMETER HubUri
    Base URI of the central hub service for registration and status checks (e.g. "https://hub.example.com").

.PARAMETER RegistrationTimeout
    (Optional) Seconds to wait for initial registration and listener startup before giving up. 
    Defaults to the value configured in BotConfiguration.

.PARAMETER Token
    (Optional) Authentication token to use when communicating with the hub API.

.PARAMETER WatchDogPoolingInterval
    (Optional) Seconds between watchdog retries when checking or re-registering the bot. 
    Defaults to the value configured in BotConfiguration.

.EXAMPLE
    $result = Initialize-Bot `
        -BotName "MyBot" `
        -BotType "static-bot" `
        -BotVolume "C:\bots\MyBot" `
        -CallbackPort 8080 `
        -EntryPointPort 9090 `
        -EnvironmentFilePath ".\MyBot.env" `
        -HubUri "https://hub.example.com" `
        -RegistrationTimeout 60 `
        -Token "secret-token" `
        -WatchDogPoolingInterval 30

.NOTES
    - Depends on utility functions: New-BotConfiguration, Start-BotCallbackListener, and Start-BotWatchDog.
    - Supports common parameters like -Verbose and -Debug via CmdletBinding().
#>
function Initialize-Bot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)] [string] $BotId,
        [Parameter(Mandatory = $false)] [string] $BotName,
        [Parameter(Mandatory = $false)] [string] $BotType,
        [Parameter(Mandatory = $false)] [string] $BotVolume,
        [Parameter(Mandatory = $false)] [string] $CallbackUri,
        [Parameter(Mandatory = $false)] [string] $CallbackIngress,
        [Parameter(Mandatory = $false)] [string] $DriverBinaries,
        [Parameter(Mandatory = $false)] [int]    $EntryPointPort,
        [Parameter(Mandatory = $true)]  [string] $EnvironmentFilePath,
        [Parameter(Mandatory = $false)] [string] $HubUri,
        [Parameter(Mandatory = $false)] [int]    $RegistrationTimeout,
        [Parameter(Mandatory = $false)] [string] $Token,
        [Parameter(Mandatory = $false)] [int]    $WatchDogPollingInterval
    )

    # 1) Build the bot’s configuration object (endpoints, metadata, timeouts)
    $BotConfiguration = New-BotConfiguration `
        -BotId                   $BotId `
        -BotName                 $BotName `
        -BotType                 $BotType `
        -CallbackUri             $CallbackUri `
        -CallbackIngress         $CallbackIngress `
        -DriverBinaries          $DriverBinaries `
        -EntryPointPort          $EntryPointPort `
        -EnvironmentFilePath     $EnvironmentFilePath `
        -HubUri                  $HubUri `
        -RegistrationTimeout     $RegistrationTimeout `
        -Token                   $Token `
        -WatchDogPollingInterval $WatchDogPollingInterval

    # 2) Start the callback listener in the background and capture its job handle
    $botCallbackJob = Start-BotCallbackListener `
        -BotCallbackUri    $botConfiguration.Endpoints.BotCallbackUri `
        -BotCallbackPrefix $botConfiguration.Endpoints.BotCallbackPrefix `
        -BotId             $botConfiguration.Metadata.BotId `
        -BotName           $botConfiguration.Metadata.BotName `
        -BotType           $botConfiguration.Metadata.BotType `
        -HubUri            $botConfiguration.Endpoints.HubUri `
        -Timeout           $botConfiguration.Timeouts.RegistrationTimeout

    # 3) Start the watchdog to monitor and re-register the bot until the callback job completes
    $botWatchdogJob = Start-BotWatchDog `
        -BotCallbackUri    $botConfiguration.Endpoints.BotCallbackUri `
        -BotCallbackPrefix $botConfiguration.Endpoints.BotCallbackPrefix `
        -BotId             $botConfiguration.Metadata.BotId `
        -BotName           $botConfiguration.Metadata.BotName `
        -BotType           $botConfiguration.Metadata.BotType `
        -HubUri            $botConfiguration.Endpoints.HubUri `
        -Timeout           $botConfiguration.Timeouts.RegistrationTimeout `
        -ParentTask        $botCallbackJob `
        -PollingInterval   $botConfiguration.Timeouts.WatchDogPollingInterval

    # Return an object with configuration and job handles for upstream monitoring or cleanup
    return [PSCustomObject]@{
        Configuration = $botConfiguration
        CallbackJob   = $botCallbackJob
        WatchdogJob   = $botWatchdogJob
    }
}

function Initialize-BotByConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [PSCustomObject] $BotConfiguration
    )

    # 1) Start the callback listener in the background and capture its job handle
    $botCallbackJob = Start-BotCallbackListener `
        -BotCallbackIngress $botConfiguration.Endpoints.BotCallbackIngress `
        -BotCallbackPrefix  $botConfiguration.Endpoints.BotCallbackPrefix `
        -BotCallbackUri     $botConfiguration.Endpoints.BotCallbackUri `
        -BotId              $botConfiguration.Metadata.BotId `
        -BotName            $botConfiguration.Metadata.BotName `
        -BotType            $botConfiguration.Metadata.BotType `
        -HubUri             $botConfiguration.Endpoints.HubUri `
        -Timeout            $botConfiguration.Timeouts.RegistrationTimeout

    # 2) Start the watchdog to monitor and re-register the bot until the callback job completes
    $botWatchdogJob = Start-BotWatchDog `
        -BotCallbackIngress $botConfiguration.Endpoints.BotCallbackIngress `
        -BotCallbackUri     $botConfiguration.Endpoints.BotCallbackUri `
        -BotCallbackPrefix  $botConfiguration.Endpoints.BotCallbackPrefix `
        -BotId              $botConfiguration.Metadata.BotId `
        -BotName            $botConfiguration.Metadata.BotName `
        -BotType            $botConfiguration.Metadata.BotType `
        -HubUri             $botConfiguration.Endpoints.HubUri `
        -Timeout            $botConfiguration.Timeouts.RegistrationTimeout `
        -ParentTask         $botCallbackJob `
        -PollingInterval    $botConfiguration.Timeouts.WatchDogPollingInterval

    # Return an object with configuration and job handles for upstream monitoring or cleanup
    return [PSCustomObject]@{
        Configuration = $BotConfiguration
        CallbackJob   = $botCallbackJob
        WatchdogJob   = $botWatchdogJob
    }
}
