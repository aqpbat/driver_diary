@echo off
rem Opens the driver shift diary in the browser on Windows.
rem Nothing is installed or built: PowerShell, which Windows already has,
rem serves the ready-made web client from demo\web on this computer only,
rem and the client talks to the API deployed on Railway.
rem Close this window to stop.
rem
rem Everything below the #PS1 line is PowerShell; this file runs it from itself.
set "DEMO_SELF=%~f0"
set "DEMO_ROOT=%~dp0web"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = Get-Content -Raw -LiteralPath $env:DEMO_SELF; Invoke-Expression $t.Substring($t.IndexOf(\"#PS1\" + [char]13))"
pause
exit /b
#PS1
$root = [IO.Path]::GetFullPath($env:DEMO_ROOT)
if (-not (Test-Path -LiteralPath (Join-Path $root "index.html"))) {
  Write-Host "demo\web was not found next to this file."
  return
}

$types = @{
  ".html" = "text/html; charset=utf-8"; ".js" = "application/javascript"
  ".json" = "application/json"; ".css" = "text/css"; ".png" = "image/png"
  ".ico" = "image/x-icon"; ".ttf" = "font/ttf"; ".otf" = "font/otf"
  ".wasm" = "application/wasm"
}

# The first free port out of a few: another copy may already be running.
$listener = $null
foreach ($port in 8765..8769) {
  $candidate = New-Object System.Net.HttpListener
  $candidate.Prefixes.Add("http://localhost:$port/")
  try { $candidate.Start(); $listener = $candidate; break } catch { }
}
if ($null -eq $listener) {
  Write-Host "Could not start a local server: ports 8765-8769 are busy."
  return
}

$url = "http://localhost:$port/"
Write-Host "The diary is open at $url"
Write-Host "Close this window to stop."
try { Start-Process chrome $url } catch { Start-Process $url }

while ($listener.IsListening) {
  $context = $listener.GetContext()
  $response = $context.Response
  try {
    $path = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath).TrimStart("/")
    if ($path -eq "") { $path = "index.html" }
    $file = [IO.Path]::GetFullPath((Join-Path $root $path))
    # Only files inside demo\web are served.
    $inside = $file.StartsWith($root + [IO.Path]::DirectorySeparatorChar)
    if ($inside -and (Test-Path -LiteralPath $file -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($file)
      $type = $types[[IO.Path]::GetExtension($file).ToLower()]
      if ($null -eq $type) { $type = "application/octet-stream" }
      $response.ContentType = $type
      $response.ContentLength64 = $bytes.Length
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $response.StatusCode = 404
    }
  } catch {
    $response.StatusCode = 500
  } finally {
    $response.Close()
  }
}
