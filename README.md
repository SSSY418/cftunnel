# Cloudflare One-Click Tunnel

**English** ｜ [中文](README.zh-CN.md)

Expose any local HTTP port to the public internet in seconds — **no Cloudflare account, no domain, no configuration required**.

## Usage (three steps)

1. Double-click `cf-tunnel-en.cmd` (English build) — or `cf-tunnel.cmd` for the Chinese build
2. Type your local port (press Enter for the default `8080`)
3. Wait 2–10 seconds. When `https://xxxx.trycloudflare.com` appears, that is your public URL (already copied to the clipboard)

To stop the tunnel, press `Ctrl + C` in the window.

## Command line

```bat
cf-tunnel-en.cmd                 :: interactive mode, prompts for a port
cf-tunnel-en.cmd 8080            :: tunnel http://localhost:8080
cf-tunnel-en.cmd 3000            :: tunnel http://localhost:3000
cf-tunnel-en.cmd 0 http://127.0.0.1:5000   :: custom full URL (pass 0 as the first argument)
cf-tunnel-en.cmd 8080 -Protocol quic       :: switch transport protocol
```

Arguments:

| Argument | Description |
| --- | --- |
| `Port` (1st) | Local port; Enter defaults to 8080; pass `0` to ignore it and use a full URL instead |
| `Url` (2nd) | Full local address, e.g. `http://localhost:3000` |
| `-Protocol` | `http2` (default, TCP 7844, more firewall-friendly) / `quic` (UDP, usually faster) / `auto` |

## What it does for you

- Installs `cloudflared` automatically when missing: it probes several mirrors (`gh-proxy.com` / `ghproxy.net` / GitHub official / `ghfast.top` / `github.moeyy.xyz`), downloads from the fastest one, and falls back to `winget`. It installs to `%LOCALAPPDATA%\cf-tunnel\bin\cloudflared.exe` and **only downloads once**.
- Checks whether something is actually listening on the port, and warns you early (otherwise you would just see a 502 in the browser).
- Starts the tunnel, extracts the public URL from the logs, highlights it, and copies it to the clipboard.
- Suggests retrying with another protocol when the tunnel fails.

## FAQ

**The URL shows 502 / Bad Gateway**
Your local service is not running, or the port is wrong. First confirm `http://localhost:<port>` works in a browser.

**`failed to dial to edge` / cannot reach Cloudflare edge**
Your network is blocking port 7844. Retry with another protocol: `cf-tunnel.cmd 8080 -Protocol quic` (or `-Protocol http2`), and use a proxy if necessary.

**Is the URL temporary?**
Yes. Quick Tunnels are free and temporary: **a new address is issued on every restart** and long-term availability is not guaranteed. They are a good fit for demos, integration testing, or reaching a local service from your phone.
For a stable hostname, use a named tunnel instead (`cloudflared tunnel login` → `tunnel create` → `tunnel route dns`) — that is a different workflow.

**I want a fixed address / access control**
That requires a Cloudflare account and your own domain. This tool does not cover that scenario.

## Requirements

- Windows 10 / 11
- Windows PowerShell 5.1 or PowerShell 7 (the built-in 5.1 is enough)
- Internet access; if your network blocks TCP 7844 or UDP, bring your own proxy

## Files

Two builds, identical in behaviour — only the console language differs:

| Build | Entry point | Logic |
| --- | --- | --- |
| English | `cf-tunnel-en.cmd` | `cf-tunnel-en.ps1` |
| 中文 | `cf-tunnel.cmd` | `cf-tunnel.ps1` |

The `.cmd` file is the double-click entry point (it forwards to PowerShell, so you never have to change the execution policy). Both `.ps1` files run on Windows PowerShell 5.1 and PowerShell 7.

## License

MIT
