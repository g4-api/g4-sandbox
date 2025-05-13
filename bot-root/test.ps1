$StatusCode = 200
    $Base64ResponseContent = "eyJtZXNzYWdlIjoiRzQgSFRUUCBRdWVyeVN0cmluZyBMaXN0ZW5lciBCb3QgdjEuMCJ9"   
        
        
        try{
        # Decode the Base64 payload into a UTF-8 string
        $decodedContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64ResponseContent))

        # Convert the UTF-8 string into a byte array for writing
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($decodedContent)

        # Set headers for a normal (non-error) response
        $l = $buffer.Count
        #$l = $buffer.Length
        # Buffer is ready�body will be written in the finally block
    }
    catch {
        # Build a JSON object with error details
        $errorObject = @{
            error   = $_.Exception.GetBaseException().StackTrace
            message = $_.Exception.GetBaseException().Message
        } | ConvertTo-Json -Depth 5 -Compress

        # Encode the error JSON into bytes
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($errorObject)

        # Log a warning with the error message
        Write-Warning "Error writing response: $($_.Exception.GetBaseException().Message)"
    }
    finally {
    }