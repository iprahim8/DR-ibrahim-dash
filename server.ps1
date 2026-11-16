$port = 8080
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$jsonPath = Join-Path $root "dashboard_data.json"
$indexPath = Join-Path $root "index.html"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Dr Araby Dashboard Server Running!" -ForegroundColor Green
Write-Host " URL: http://localhost:$port" -ForegroundColor Yellow
Write-Host " Database: $jsonPath" -ForegroundColor Gray
Write-Host "=====================================================" -ForegroundColor Cyan

Start-Process "http://localhost:$port"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $req = $context.Request
        $res = $context.Response
        $res.Headers.Add("Access-Control-Allow-Origin", "*")
        $res.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
        $res.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

        if ($req.HttpMethod -eq "OPTIONS") {
            $res.StatusCode = 200
            $res.Close()
            continue
        }

        $path = $req.Url.AbsolutePath

        if (($path -eq "/api/save" -or $path -eq "/dashboard_data.json") -and ($req.HttpMethod -eq "POST" -or $req.HttpMethod -eq "PUT")) {
            try {
                $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                $body = $reader.ReadToEnd()
                $reader.Close()

                # Validate JSON before writing
                $null = $body | ConvertFrom-Json
                [System.IO.File]::WriteAllText($jsonPath, $body, [System.Text.UTF8Encoding]::new($false))

                $respBytes = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                $res.ContentType = "application/json; charset=utf-8"
                $res.StatusCode = 200
                $res.OutputStream.Write($respBytes, 0, $respBytes.Length)
            } catch {
                $errBytes = [System.Text.Encoding]::UTF8.GetBytes('{"ok":false,"error":"Invalid JSON"}')
                $res.ContentType = "application/json; charset=utf-8"
                $res.StatusCode = 400
                $res.OutputStream.Write($errBytes, 0, $errBytes.Length)
            }
            $res.Close()
            continue
        }

        if ($path -eq "/dashboard_data.json" -or $path -eq "/api/data") {
            if (Test-Path $jsonPath) {
                $bytes = [System.IO.File]::ReadAllBytes($jsonPath)
                $res.ContentType = "application/json; charset=utf-8"
                $res.Headers.Add("Cache-Control", "no-store, no-cache, must-revalidate")
                $res.StatusCode = 200
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $res.StatusCode = 404
            }
            $res.Close()
            continue
        }

        if ($path -eq "/" -or $path -eq "/index.html") {
            $bytes = [System.IO.File]::ReadAllBytes($indexPath)
            $res.ContentType = "text/html; charset=utf-8"
            $res.Headers.Add("Cache-Control", "no-store, no-cache, must-revalidate")
            $res.StatusCode = 200
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.Close()
            continue
        }

        $res.StatusCode = 404
        $res.Close()
    }
} finally {
    $listener.Stop()
}
