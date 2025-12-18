## Basic PowerShell HTTP listener

# Port to listen on (e.g., 8080 or 80)
$port = 80

# Prefix to listen on - use '+' to listen on all interfaces
$uriPrefix = "http://+:$port/"

# Create the HttpListener object
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($uriPrefix)

Write-Host "Starting Internal Web Listener on $uriPrefix"

try {
    # Start listening for requests
    $listener.Start()

    # Loop to continuously listen
    while ($true) {
        Write-Host "Waiting for a connection..."

        # GetContext blocks until a request is received
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # --- Logging the Request ---
        $logEntry = @"
[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")]
Source IP: $($request.RemoteEndPoint.Address)
Method: $($request.HttpMethod)
URL: $($request.Url.AbsoluteUri)
User-Agent: $($request.UserAgent)
Headers:
$($request.Headers | Out-String)
---
"@
        Write-Host $logEntry -ForegroundColor Green

        # If it's a POST request, log the body as well
        if ($request.HttpMethod -eq 'POST' -and $request.HasEntityBody) {
            $stream = $request.InputStream
            $reader = New-Object System.IO.StreamReader($stream, $request.ContentEncoding)
            $postBody = $reader.ReadToEnd()
            Write-Host "Body Content:`n$postBody" -ForegroundColor Yellow
            Write-Host "---"
        }
        
        # --- Preparing the Response (Simple 'OK') ---
        $responseString = "OK"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)

        # Set content length and content type
        $response.ContentLength64 = $buffer.Length
        $response.ContentType = "text/plain"

        # Write the response back to the client
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
finally {
    # Clean up the listener when the script is stopped (e.g., via Ctrl+C)
    if ($listener.IsListening) {
        $listener.Stop()
        Write-Host "Listener stopped."
    }
}
