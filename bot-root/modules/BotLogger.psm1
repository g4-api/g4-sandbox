<#
.SYNOPSIS
    Writes a timestamped log message with a named level and optional color coding.

.DESCRIPTION
    Write-Log emits lines prefixed with an ISO 8601 UTC timestamp, a three-letter level code, and your message, e.g.:
        2025-05-02T12:34:56.789Z - INF: Service started.
    You specify the full level name (Information, Warning, Error, Debug, Verbose, Critical),
    and internally it’s mapped to a three-letter code.  
    When -UseColor is specified, it uses distinct console colors for each level:
      • INF > (no color; uses default console color)
      • WRN > Yellow
      • ERR > Red
      • DBG > DarkGray
      • VRB > Cyan
      • CRT > DarkRed

.PARAMETER Level
    The full log level name. Must be one of:
      Information, Warning, Error, Debug, Verbose, Critical

.PARAMETER Message
    The text of the log message.

.PARAMETER UseColor
    Switch to enable colorized output.

.EXAMPLE
    # Plain text
    Write-Log -Level Information -Message "Service started."

.EXAMPLE
    # Colorized
    Write-Log -Level Critical -Message "System failure imminent!" -UseColor
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Information','Warning','Error','Debug','Verbose','Critical')]
        [string] $Level,        # Full name of the log level
        [string] $Message,      # The log message text
        [switch] $UseColor      # Enable colorized output
    )

    # Ensure $Message is never $null or $false; default to an empty string if no message was provided
    $Message = if(-not $Message) { [string]::Empty } else { $Message }

    # Generate ISO 8601 UTC timestamp with milliseconds
    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    # Map full level name to a three-letter code
    $code = switch ($Level) {
        'Information' { 'INF' }
        'Warning'     { 'WRN' }
        'Error'       { 'ERR' }
        'Debug'       { 'DBG' }
        'Verbose'     { 'VRB' }
        'Critical'    { 'CRT' }
    }

    # Construct the log line
    $logLine = "$($timestamp) - $($code): $($Message)"

    if ($UseColor) {
        # Determine color for each level; VRB uses default console color
        $color = switch ($code) {
            'INF' { $null }
            'WRN' { 'Yellow' }
            'ERR' { 'Red' }
            'DBG' { 'DarkGray' }
            'VRB' { 'Cyan' }
            'CRT' { 'DarkRed' }
        }

        if ($color) {
            # Write with the chosen foreground color
            Write-Host $logLine -ForegroundColor $color
        }
        else {
            # VRB or unspecified: write without color
            Write-Host $logLine
        }
    }
    else {
        # No color requested
        Write-Host $logLine
    }
}

Export-ModuleMember -Function Write-Log