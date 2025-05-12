function New-Result {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int] $StatusCode,
        [Parameter(Mandatory)] [string] $Content
    )
    $parsed = $null
    
    try { $parsed = $Content | ConvertFrom-Json -ErrorAction Stop } catch {}

    return [PSCustomObject]@{
        Base64Content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Content))
        ContentType   = "application/json; charset=utf-8"
        JsonValue     = $Content
        StatusCode    = $StatusCode
        Value         = if ($parsed) { $parsed } else { $Content }
    }
}

# Clear any old variable
Remove-Variable response -ErrorAction SilentlyContinue

 $content = Get-Content -Path "/mnt/c/g4-bots-volume/g4-http-listener-bot/bot/automation.json"
 $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
 $Base64Request     = [System.Convert]::ToBase64String($bytes)

 # PowerShell Core: never throw on 4xx/5xx
$r = Invoke-WebRequest `
  -Uri                     "http://192.168.1.13:9944/api/v4/g4/automation/base64/invoke" `
  -Method                  Post `
  -Body                    $Base64Request `
  -ContentType             'text/plain' `
  -ErrorAction              Continue `
  -ErrorVariable            networkError `
  -SkipHttpErrorCheck `
  -OutVariable              response `
  -ConnectionTimeoutSeconds 30


  if($networkError) {
    Write-Host $networkError
  }

  if($response) {
    Write-Host $response
  }

  $webResponse = $response[-1]

  $content = [System.Text.Encoding]::UTF8.GetString($webResponse.Content)
  $a = New-Result -StatusCode $webResponse.StatusCode -Content $content
  $c=""