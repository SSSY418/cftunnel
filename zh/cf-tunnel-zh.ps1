<#
  Cloudflare One-Click Tunnel (Quick Tunnel) - Chinese build
  ------------------------------------------------------------
  No login, no domain, no configuration: expose a local HTTP port to
  the public internet in seconds, with a temporary
  https://xxxx.trycloudflare.com address.

  This is the Chinese build (folder zh/). The English build is en/cf-tunnel-en.ps1.

  Security: a Quick Tunnel is public. Anyone who has the URL can reach your local
  service, and there is no login in front of it. See the security notes in
  README.zh-CN.md before exposing anything sensitive.

  Usage:
    cf-tunnel-zh.cmd                 # double-click, then enter a port
    cf-tunnel-zh.cmd 8080            # tunnel http://localhost:8080
    cf-tunnel-zh.cmd 3000            # tunnel http://localhost:3000
    cf-tunnel-zh.cmd 0 http://127.0.0.1:5000   # fully custom URL (0 = ignore the port)
    cf-tunnel-zh.cmd 8080 -Protocol quic       # switch protocol (default http2, more firewall-friendly)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][int]$Port = 0,
    [Parameter(Position = 1)][string]$Url,
    [ValidateSet('http2', 'quic', 'auto')][string]$Protocol = 'http2'
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
try { $Host.UI.RawUI.WindowTitle = 'Cloudflare 一键隧道' } catch { }

function Write-Line($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Write-Banner {
    Write-Host ''
    Write-Host '  ========================================================' -ForegroundColor DarkCyan
    Write-Host '            Cloudflare 一键隧道  (Quick Tunnel)' -ForegroundColor Cyan
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
        Write-Host '  请输入要暴露的本地端口（直接回车 = 8080）' -ForegroundColor Gray
        Write-Host '  也可以直接粘贴完整地址，如 http://localhost:3000' -ForegroundColor DarkGray
        $answer = Read-Host '  端口'
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

    Write-Step '首次运行，正在下载 cloudflared（约 55 MB，仅一次）...'
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
    Write-Host '      正在探测可用下载源...' -ForegroundColor DarkGray
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
            Write-Host ("      可用源 {0,6} ms : {1}" -f $p.Ms, ($p.Url -replace 'https://github.com/cloudflare/cloudflared/releases/latest/download/', '<gh>/')) -ForegroundColor DarkGray
        }
    }
    else {
        Write-Warn '所有镜像探测超时，仍按默认顺序尝试...'
        $ordered = $sources
    }

    $hasCurl = [bool](Get-Command curl.exe -ErrorAction SilentlyContinue)

    foreach ($src in $ordered) {
        try {
            Write-Step "下载: $src"
            if ($hasCurl) {
                & curl.exe -L --fail --connect-timeout 10 --max-time 600 --progress-bar -o $exe $src
                if ($LASTEXITCODE -ne 0) { throw "curl 退出码 $LASTEXITCODE" }
            }
            else {
                Invoke-WebRequest -Uri $src -OutFile $exe -UseBasicParsing -TimeoutSec 600
            }

            if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 5MB) {
                throw '文件大小异常，可能下载不完整'
            }

            $version = (& $exe --version 2>&1 | Out-String).Trim()
            if (-not $version) { throw '下载的文件无法运行' }

            Write-Ok "cloudflared 已就绪：$version"
            Write-Host "      位置: $exe" -ForegroundColor DarkGray
            return $exe
        }
        catch {
            Write-Warn "该源失败：$($_.Exception.Message)"
            Remove-Item $exe -Force -ErrorAction SilentlyContinue
        }
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Warn '改用 winget 安装 cloudflared ...'
        try {
            & winget install --id Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements --silent
            $cmd = Get-Command cloudflared.exe -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.Source) { Write-Ok "cloudflared 已就绪：$($cmd.Source)"; return $cmd.Source }
        }
        catch { }
    }

    Write-Err 'cloudflared 自动安装失败，请手动下载后放进 PATH：'
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
Write-Step "本地目标 : $target"
Write-Step "隧道协议 : $Protocol"
Write-Line '      提示: 快速隧道地址每次重启都会变化，且无需 Cloudflare 账号。' 'DarkGray'

$exe = Resolve-Cloudflared
if (-not $exe) {
    Write-Host ''
    Read-Host '  按回车键退出'
    exit 1
}

$alive = Test-TargetAlive $target
if ($alive -eq $false) {
    Write-Warn '该本地端口当前没有服务在监听 —— 隧道仍会建立，但打开网址会显示 502。'
    Write-Host '      请先启动你的本地服务，再重新运行本工具。' -ForegroundColor DarkGray
    Write-Host ''
}
elseif ($alive -eq $true) {
    Write-Ok '本地服务已就绪'
}

Write-Host ''
Write-Step '正在建立隧道，请稍候（通常 2~10 秒）...'
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
        Write-Host '  #   你的公网地址已经就绪，复制到浏览器即可访问:        #' -ForegroundColor Green
        Write-Host '  #                                                      #' -ForegroundColor Green
        Write-Host '  ########################################################' -ForegroundColor Green
        Write-Host ''
        Write-Host "      $($script:publicUrl)" -ForegroundColor Yellow
        Write-Host ''
        Write-Warn '注意：该地址在公网公开，任何人拿到都能访问你本机这个服务——别用来暴露后台或数据库'
        Write-Host '  (地址已复制到剪贴板，Ctrl+C 即可关闭隧道)' -ForegroundColor DarkGray
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
    Write-Ok "隧道已关闭：$($script:publicUrl) 已失效"
}
elseif ($script:failedHint) {
    Write-Err '隧道未能建立：可能是网络无法连接 Cloudflare 边缘节点。'
    Write-Host '      可以试试其它协议后再运行一次，例如：' -ForegroundColor Gray
    Write-Host '        cf-tunnel-zh.cmd 8080 -Protocol quic' -ForegroundColor DarkGray
    Write-Host '        cf-tunnel-zh.cmd 8080 -Protocol auto' -ForegroundColor DarkGray
    Write-Host '      若仍失败，请检查代理/防火墙是否放行 TCP 7844。' -ForegroundColor DarkGray
}
else {
    Write-Warn '隧道已退出'
}
Write-Host ''
Read-Host '  按回车键关闭窗口'
