<#
  Cloudflare One-Click Tunnel (Quick Tunnel) - English build
  ------------------------------------------------------------
  No login, no domain, no configuration: expose a local HTTP port to
  the public internet in seconds, with a temporary
  https://xxxx.trycloudflare.com address.

  This is the English build. The Chinese build is cf-tunnel-zh.ps1.

  Usage:
    cf-tunnel-en.cmd                 # double-click, then enter a port
    cf-tunnel-en.cmd 8080            # tunnel http://localhost:8080
    cf-tunnel-en.cmd 3000            # tunnel http://localhost:3000
    cf-tunnel-en.cmd 0 http://127.0.0.1:5000   # fully custom URL (0 = ignore the port)
    cf-tunnel-en.cmd 8080 -Protocol quic       # switch protocol (default http2, more firewall-friendly)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][int]$Port = 0,
    [Parameter(Position = 1)][string]$Url,
    [ValidateSet('http2', 'quic', 'auto')][string]$Protocol = 'http2'
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
try { $Host.UI.RawUI.WindowTitle = 'Cloudflare One-Click Tunnel' } catch { }

function Write-Line($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Write-Banner {
    Write-Host ''
    Write-Host '  ========================================================' -ForegroundColor DarkCyan
    Write-Host '        Cloudflare One-Click Tunnel  (Quick Tunnel)' -ForegroundColor Cyan
    Write-Host '  ========================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-Step($text) { Write-Host "[*] $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "[v] $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "[!] $text" -ForegroundColor Yellow }
function Write-Err($text)  { Write-Host "[x] $text" -ForegroundColor Red }

# ---------------------------------------------------------------- target address
function Resolve-Target {
    if ($Url) { return $Url }

    if ($Port -le 0) {
        Write-Host '  Enter the local port to expose (press Enter = 8080)' -ForegroundColor Gray
        Write-Host '  You can also paste a full URL, e.g. http://localhost:3000' -ForegroundColor DarkGray
        $answer = Read-Host '  Port'
        if ([string]::IsNullOrWhiteSpace($answer)) {
            $Url = 'http://localhost:8080'
        }
        elseif ($answer -match '^\d+$') {
            $Port = [int]$answer
            $Url  = "http://localhost:$Port"
        }
        else {
            $Url = $answer.Trim()
        }
    }
    else {
        $Url = "http://localhost:$Port"
    }

    if ($Url -notmatch '^[a-zA-Z]+://') { $Url = "http://$Url" }
    return $Url
}

# ---------------------------------------------------------------- cloudflared
function Resolve-Cloudflared {
    foreach ($name in @('cloudflared.exe', 'cloudflared')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return $cmd.Source }
    }

    $dir = Join-Path $env:LOCALAPPDATA 'cf-tunnel\bin'
    $exe = Join-Path $dir 'cloudflared.exe'
    if (Test-Path $exe) { return $exe }

    Write-Step 'First run: downloading cloudflared (~55 MB, one time only)...'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $file = "cloudflared-windows-$arch.exe"
    $sources = @(
        "https://gh-proxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/$file",
        "https://ghproxy.net/https://github.com/cloudflare/cloudflared/releases/latest/download/$file",
        "https://github.com/cloudflare/cloudflared/releases/latest/download/$file",
        "https://ghfast.top/https://github.com/cloudflare/cloudflared/releases/latest/download/$file",
        "https://github.moeyy.xyz/https://github.com/cloudflare/cloudflared/releases/latest/download/$file"
    )

    # GitHub is often blocked on direct connections inside mainland China, so
    # probe which mirror works first, then download from the fastest one.
    Write-Host '      Probing available download sources...' -ForegroundColor DarkGray
    $probe = @()
    foreach ($src in $sources) {
        $t0 = Get-Date
        try {
            $null = Invoke-WebRequest -Uri $src -Method Head -UseBasicParsing -TimeoutSec 6
            $probe += [pscustomobject]@{ Url = $src; Ms = [int]((Get-Date) - $t0).TotalMilliseconds }
        }
        catch { }
    }

    if ($probe.Count -gt 0) {
        $ordered = @($probe | Sort-Object Ms | ForEach-Object { $_.Url })
        foreach ($p in ($probe | Sort-Object Ms)) {
            Write-Host ("      source {0,6} ms : {1}" -f $p.Ms, ($p.Url -replace 'https://github.com/cloudflare/cloudflared/releases/latest/download/', '<gh>/')) -ForegroundColor DarkGray
        }
    }
    else {
        Write-Warn 'All mirrors timed out; falling back to the default order...'
        $ordered = $sources
    }

    $hasCurl = [bool](Get-Command curl.exe -ErrorAction SilentlyContinue)

    foreach ($src in $ordered) {
        try {
            Write-Step "Downloading: $src"
            if ($hasCurl) {
                & curl.exe -L --fail --connect-timeout 10 --max-time 600 --progress-bar -o $exe $src
                if ($LASTEXITCODE -ne 0) { throw "curl exit code $LASTEXITCODE" }
            }
            else {
                Invoke-WebRequest -Uri $src -OutFile $exe -UseBasicParsing -TimeoutSec 600
            }

            if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 5MB) {
                throw 'Unexpected file size; the download may be incomplete'
            }

            $version = (& $exe --version 2>&1 | Out-String).Trim()
            if (-not $version) { throw 'The downloaded file could not run' }

            Write-Ok "cloudflared is ready: $version"
            Write-Host "      Location: $exe" -ForegroundColor DarkGray
            return $exe
        }
        catch {
            Write-Warn "Source failed: $($_.Exception.Message)"
            Remove-Item $exe -Force -ErrorAction SilentlyContinue
        }
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Warn 'Falling back to winget to install cloudflared ...'
        try {
            & winget install --id Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements --silent
            $cmd = Get-Command cloudflared.exe -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.Source) { Write-Ok "cloudflared is ready: $($cmd.Source)"; return $cmd.Source }
        }
        catch { }
    }

    Write-Err 'Could not install cloudflared automatically. Download it manually and put it on PATH:'
    Write-Line '    https://github.com/cloudflare/cloudflared/releases/latest' 'DarkGray'
    return $null
}

# ---------------------------------------------------------------- port probe
function Test-TargetAlive([string]$target) {
    try {
        $uri  = [System.Uri]$target
        $host_ = if ($uri.Host) { $uri.Host } else { 'localhost' }
        $port_ = if ($uri.Port -gt 0) { $uri.Port } else { 80 }
    }
    catch { return $null }

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($host_, $port_, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne(1500, $false) -and $client.Connected) { return $true }
        return $false
    }
    catch { return $false }
    finally { $client.Close() }
}

# ---------------------------------------------------------------- main flow
Write-Banner

$target = Resolve-Target
Write-Step "Local target : $target"
Write-Step "Protocol     : $Protocol"
Write-Line '      Note: a Quick Tunnel URL changes on every restart, and needs no Cloudflare account.' 'DarkGray'

$exe = Resolve-Cloudflared
if (-not $exe) {
    Write-Host ''
    Read-Host '  Press Enter to exit'
    exit 1
}

$alive = Test-TargetAlive $target
if ($alive -eq $false) {
    Write-Warn 'Nothing is listening on that local port - the tunnel will still start, but the URL will show a 502.'
    Write-Host '      Start your local service first, then run this tool again.' -ForegroundColor DarkGray
    Write-Host ''
}
elseif ($alive -eq $true) {
    Write-Ok 'Local service is up'
}

Write-Host ''
Write-Step 'Establishing the tunnel, please wait (usually 2-10 seconds)...'
Write-Host ''

$script:publicUrl = $null
$script:failedHint = $false

& $exe tunnel --no-autoupdate --protocol $Protocol --url $target 2>&1 | ForEach-Object {
    $line = $_.ToString()

    if (-not $script:publicUrl -and $line -match 'https://[a-zA-Z0-9][a-zA-Z0-9\-]*\.trycloudflare\.com') {
        $script:publicUrl = $Matches[0]

        Write-Host ''
        Write-Host '  ########################################################' -ForegroundColor Green
        Write-Host '  #                                                      #' -ForegroundColor Green
        Write-Host '  #   Your public URL is ready - open it in a browser:   #' -ForegroundColor Green
        Write-Host '  #                                                      #' -ForegroundColor Green
        Write-Host '  ########################################################' -ForegroundColor Green
        Write-Host ''
        Write-Host "      $($script:publicUrl)" -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  (URL copied to the clipboard; press Ctrl+C to close the tunnel)' -ForegroundColor DarkGray
        Write-Host ''

        try { Set-Clipboard -Value $script:publicUrl } catch { }
    }

    if ($line -match 'failed to (dial|request)|no such host|context deadline exceeded|Unable to establish connection|failed to connect to edge') {
        $script:failedHint = $true
    }

    if ($line.Trim()) { Write-Host "  $line" -ForegroundColor DarkGray }
}

Write-Host ''
if ($script:publicUrl) {
    Write-Ok "Tunnel closed: $($script:publicUrl) is no longer valid"
}
elseif ($script:failedHint) {
    Write-Err 'Could not establish the tunnel: your network may be unable to reach the Cloudflare edge.'
    Write-Host '      Try another protocol and run it again, for example:' -ForegroundColor Gray
    Write-Host '        cf-tunnel-en.cmd 8080 -Protocol quic' -ForegroundColor DarkGray
    Write-Host '        cf-tunnel-en.cmd 8080 -Protocol auto' -ForegroundColor DarkGray
    Write-Host '      If it still fails, check that your proxy or firewall allows TCP 7844.' -ForegroundColor DarkGray
}
else {
    Write-Warn 'Tunnel exited'
}
Write-Host ''
Read-Host '  Press Enter to close this window'
