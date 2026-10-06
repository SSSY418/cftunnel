<#
  Cloudflare One-Click Tunnel (Quick Tunnel)
  ------------------------------------------------------------
  No login, no domain, no configuration: expose a local HTTP port to
  the public internet in seconds, with a temporary
  https://xxxx.trycloudflare.com address.

  Usage:
    cf-tunnel.cmd                 # double-click, then enter a port
    cf-tunnel.cmd 8080            # tunnel http://localhost:8080
    cf-tunnel.cmd 3000            # tunnel http://localhost:3000
    cf-tunnel.cmd 0 http://127.0.0.1:5000   # fully custom URL (0 = ignore the port)
    cf-tunnel.cmd 8080 -Protocol quic       # switch protocol (default http2, more firewall-friendly)
    cf-tunnel.cmd 8080 -Lang en             # force console language (auto | zh | en)

  Console messages follow the system language by default: Chinese on a
  Chinese Windows, English everywhere else. Override with -Lang.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][int]$Port = 0,
    [Parameter(Position = 1)][string]$Url,
    [ValidateSet('http2', 'quic', 'auto')][string]$Protocol = 'http2',
    [ValidateSet('auto', 'zh', 'en')][string]$Lang = 'auto'
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ---------------------------------------------------------------- messages
$EN = @{
    windowTitle      = 'Cloudflare One-Click Tunnel'
    bannerTitle      = '        Cloudflare One-Click Tunnel  (Quick Tunnel)'
    promptPort       = '  Enter the local port to expose (press Enter = 8080)'
    promptUrl        = '  You can also paste a full URL, e.g. http://localhost:3000'
    promptAsk        = '  Port'
    dlFirst          = 'First run: downloading cloudflared (~55 MB, one time only)...'
    probing          = '      Probing available download sources...'
    srcLine          = '      source {0,6} ms : {1}'
    allTimeout       = 'All mirrors timed out; falling back to the default order...'
    downloading      = 'Downloading: {0}'
    curlExit         = 'curl exit code {0}'
    badSize          = 'Unexpected file size; the download may be incomplete'
    cannotRun        = 'The downloaded file could not run'
    cfReady          = 'cloudflared is ready: {0}'
    location         = '      Location: {0}'
    srcFailed        = 'Source failed: {0}'
    wingetFallback   = 'Falling back to winget to install cloudflared ...'
    autoFail         = 'Could not install cloudflared automatically. Download it manually and put it on PATH:'
    targetLine       = 'Local target : {0}'
    protoLine        = 'Protocol     : {0}'
    noteQuick        = '      Note: a Quick Tunnel URL changes on every restart, and needs no Cloudflare account.'
    pressEnterExit   = '  Press Enter to exit'
    noListener       = 'Nothing is listening on that local port - the tunnel will still start, but the URL will show a 502.'
    startLocalFirst  = '      Start your local service first, then run this tool again.'
    localUp          = 'Local service is up'
    establishing     = 'Establishing the tunnel, please wait (usually 2-10 seconds)...'
    boxText          = '  #   Your public URL is ready - open it in a browser:   #'
    copiedClipboard  = '  (URL copied to the clipboard; press Ctrl+C to close the tunnel)'
    tunnelClosed     = 'Tunnel closed: {0} is no longer valid'
    failedTunnel     = 'Could not establish the tunnel: your network may be unable to reach the Cloudflare edge.'
    tryOtherProto    = '      Try another protocol and run it again, for example:'
    stillFails       = '      If it still fails, check that your proxy or firewall allows TCP 7844.'
    tunnelExited     = 'Tunnel exited'
    pressEnterClose  = '  Press Enter to close this window'
}

$ZH = @{
    windowTitle      = 'Cloudflare 一键隧道'
    bannerTitle      = '            Cloudflare 一键隧道  (Quick Tunnel)'
    promptPort       = '  请输入要暴露的本地端口（直接回车 = 8080）'
    promptUrl        = '  也可以直接粘贴完整地址，如 http://localhost:3000'
    promptAsk        = '  端口'
    dlFirst          = '首次运行，正在下载 cloudflared（约 55 MB，仅一次）...'
    probing          = '      正在探测可用下载源...'
    srcLine          = '      可用源 {0,6} ms : {1}'
    allTimeout       = '所有镜像探测超时，仍按默认顺序尝试...'
    downloading      = '下载: {0}'
    curlExit         = 'curl 退出码 {0}'
    badSize          = '文件大小异常，可能下载不完整'
    cannotRun        = '下载的文件无法运行'
    cfReady          = 'cloudflared 已就绪：{0}'
    location         = '      位置: {0}'
    srcFailed        = '该源失败：{0}'
    wingetFallback   = '改用 winget 安装 cloudflared ...'
    autoFail         = 'cloudflared 自动安装失败，请手动下载后放进 PATH：'
    targetLine       = '本地目标 : {0}'
    protoLine        = '隧道协议 : {0}'
    noteQuick        = '      提示: 快速隧道地址每次重启都会变化，且无需 Cloudflare 账号。'
    pressEnterExit   = '  按回车键退出'
    noListener       = '该本地端口当前没有服务在监听 —— 隧道仍会建立，但打开网址会显示 502。'
    startLocalFirst  = '      请先启动你的本地服务，再重新运行本工具。'
    localUp          = '本地服务已就绪'
    establishing     = '正在建立隧道，请稍候（通常 2~10 秒）...'
    boxText          = '  #   你的公网地址已经就绪，复制到浏览器即可访问:        #'
    copiedClipboard  = '  (地址已复制到剪贴板，Ctrl+C 即可关闭隧道)'
    tunnelClosed     = '隧道已关闭：{0} 已失效'
    failedTunnel     = '隧道未能建立：可能是网络无法连接 Cloudflare 边缘节点。'
    tryOtherProto    = '      可以试试其它协议后再运行一次，例如：'
    stillFails       = '      若仍失败，请检查代理/防火墙是否放行 TCP 7844。'
    tunnelExited     = '隧道已退出'
    pressEnterClose  = '  按回车键关闭窗口'
}

if ($Lang -eq 'auto') {
    $isZh = ($PSUICulture -match '^zh') -or ([System.Globalization.CultureInfo]::CurrentUICulture.Name -match '^zh')
    $Lang = if ($isZh) { 'zh' } else { 'en' }
}
$M = if ($Lang -eq 'zh') { $ZH } else { $EN }

try { $Host.UI.RawUI.WindowTitle = $M.windowTitle } catch { }

function Write-Line($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Write-Banner {
    Write-Host ''
    Write-Host '  ========================================================' -ForegroundColor DarkCyan
    Write-Host $M.bannerTitle -ForegroundColor Cyan
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
        Write-Host $M.promptPort -ForegroundColor Gray
        Write-Host $M.promptUrl -ForegroundColor DarkGray
        $answer = Read-Host $M.promptAsk
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

    Write-Step $M.dlFirst
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
    Write-Host $M.probing -ForegroundColor DarkGray
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
            Write-Host ($M.srcLine -f $p.Ms, ($p.Url -replace 'https://github.com/cloudflare/cloudflared/releases/latest/download/', '<gh>/')) -ForegroundColor DarkGray
        }
    }
    else {
        Write-Warn $M.allTimeout
        $ordered = $sources
    }

    $hasCurl = [bool](Get-Command curl.exe -ErrorAction SilentlyContinue)

    foreach ($src in $ordered) {
        try {
            Write-Step ($M.downloading -f $src)
            if ($hasCurl) {
                & curl.exe -L --fail --connect-timeout 10 --max-time 600 --progress-bar -o $exe $src
                if ($LASTEXITCODE -ne 0) { throw ($M.curlExit -f $LASTEXITCODE) }
            }
            else {
                Invoke-WebRequest -Uri $src -OutFile $exe -UseBasicParsing -TimeoutSec 600
            }

            if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 5MB) {
                throw $M.badSize
            }

            $version = (& $exe --version 2>&1 | Out-String).Trim()
            if (-not $version) { throw $M.cannotRun }

            Write-Ok ($M.cfReady -f $version)
            Write-Host ($M.location -f $exe) -ForegroundColor DarkGray
            return $exe
        }
        catch {
            Write-Warn ($M.srcFailed -f $_.Exception.Message)
            Remove-Item $exe -Force -ErrorAction SilentlyContinue
        }
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Warn $M.wingetFallback
        try {
            & winget install --id Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements --silent
            $cmd = Get-Command cloudflared.exe -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.Source) { Write-Ok ($M.cfReady -f $cmd.Source); return $cmd.Source }
        }
        catch { }
    }

    Write-Err $M.autoFail
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
Write-Step ($M.targetLine -f $target)
Write-Step ($M.protoLine -f $Protocol)
Write-Line $M.noteQuick 'DarkGray'

$exe = Resolve-Cloudflared
if (-not $exe) {
    Write-Host ''
    Read-Host $M.pressEnterExit
    exit 1
}

$alive = Test-TargetAlive $target
if ($alive -eq $false) {
    Write-Warn $M.noListener
    Write-Host $M.startLocalFirst -ForegroundColor DarkGray
    Write-Host ''
}
elseif ($alive -eq $true) {
    Write-Ok $M.localUp
}

Write-Host ''
Write-Step $M.establishing
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
        Write-Host $M.boxText -ForegroundColor Green
        Write-Host '  #                                                      #' -ForegroundColor Green
        Write-Host '  ########################################################' -ForegroundColor Green
        Write-Host ''
        Write-Host "      $($script:publicUrl)" -ForegroundColor Yellow
        Write-Host ''
        Write-Host $M.copiedClipboard -ForegroundColor DarkGray
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
    Write-Ok ($M.tunnelClosed -f $script:publicUrl)
}
elseif ($script:failedHint) {
    Write-Err $M.failedTunnel
    Write-Host $M.tryOtherProto -ForegroundColor Gray
    Write-Host '        cf-tunnel.cmd 8080 -Protocol quic' -ForegroundColor DarkGray
    Write-Host '        cf-tunnel.cmd 8080 -Protocol auto' -ForegroundColor DarkGray
    Write-Host $M.stillFails -ForegroundColor DarkGray
}
else {
    Write-Warn $M.tunnelExited
}
Write-Host ''
Read-Host $M.pressEnterClose
