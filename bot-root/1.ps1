# Catch Ctrl+C via the Console.CancelKeyPress CLR event
[Console]::add_CancelKeyPress({
      param($sender,$e)
      
      # tell the runtime “don't abort immediately”
      $e.Cancel = $true

      # record and report
      Write-Host "Caught Ctrl+C"

      # now exit *gracefully* so ProcessExit fires
      Write-Host "Exiting..."
      Start-Sleep -Seconds 10
})

# 2) Catch process exit
[AppDomain]::CurrentDomain.add_ProcessExit({
    Write-Host "Process exiting"
})

Write-Host "Running in a real console... press Ctrl+C to test."

# spin until something happens
while ($true) {
    Start-Sleep 1
}
