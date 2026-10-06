# Cloudflare 一键隧道

[English](README.md) ｜ **中文**

**中文版：** `zh/cf-tunnel-zh.cmd` ｜ **English build:** `en/cf-tunnel-en.cmd`

把本机任意 HTTP 端口几秒钟暴露到公网，**不需要 Cloudflare 账号、不需要域名、不需要配置**。

## 怎么用（三步）

1. 打开 `zh` 文件夹，双击 `cf-tunnel-zh.cmd`（英文版在 `en/cf-tunnel-en.cmd`）
2. 输入本地端口（直接回车 = 8080）
3. 等 2~10 秒，屏幕上出现 `https://xxxx.trycloudflare.com` 就是你的公网地址（已自动复制到剪贴板）

关闭：在窗口里按 `Ctrl + C`。

## 命令行用法

```bat
cd zh
cf-tunnel-zh.cmd                 :: 双击式交互，按提示输端口
cf-tunnel-zh.cmd 8080            :: 映射 http://localhost:8080
cf-tunnel-zh.cmd 3000            :: 映射 http://localhost:3000
cf-tunnel-zh.cmd 0 http://127.0.0.1:5000   :: 自定义完整地址（第一个参数填 0）
cf-tunnel-zh.cmd 8080 -Protocol quic       :: 换传输协议
```

参数说明：

| 参数 | 说明 |
| --- | --- |
| `Port`（第 1 个） | 本地端口，回车默认 8080；填 `0` 表示忽略、改用完整 URL |
| `Url`（第 2 个） | 完整本地地址，如 `http://localhost:3000` |
| `-Protocol` | `http2`（默认，走 TCP 7844，对防火墙更友好）/ `quic`（走 UDP，通常更快）/ `auto` |

## 它自动做了什么

- 找不到 `cloudflared` 时自动安装：先探测可用镜像（`gh-proxy.com` / `ghproxy.net` / GitHub 官方 / `ghfast.top` / `github.moeyy.xyz`），按响应速度排序下载，最后兜底用 `winget`；安装到 `%LOCALAPPDATA%\cf-tunnel\bin\cloudflared.exe`，**只下一次**。
- 检测端口是否真的有服务在监听，没有会提前提醒（否则打开网址只会看到 502）。
- 启动隧道、从日志里抓出公网地址、高亮显示并写入剪贴板。
- 隧道失败时提示换协议重试。

## 常见问题

**打开网址显示 502 / Bad Gateway**
本地服务没起来或端口填错了。先确认浏览器访问 `http://localhost:端口` 正常。

**提示 `failed to dial to edge` / 连不上边缘节点**
网络出不去 7844 端口。换协议再试：`cf-tunnel-zh.cmd 8080 -Protocol quic`（或反过来用 `-Protocol http2`），必要时挂代理。

**地址是临时的？**
是的。Quick Tunnel 属于免费临时隧道，**每次重启都会换一个新地址**，且不保证长期可用，适合临时演示、联调、手机访问本机服务。
需要固定域名请改用命名隧道（`cloudflared tunnel login` → `tunnel create` → `tunnel route dns`），那是另一套流程。

**想固定地址 / 加访问控制**
那就需要 Cloudflare 账号 + 自己的域名，本工具不覆盖这个场景。

## 环境要求

- Windows 10 / 11
- Windows PowerShell 5.1 或 PowerShell 7（系统自带 5.1 即可）
- 能访问公网；网络环境出不去 7844（TCP）或 UDP 时需自备代理

## 文件

两个版本，行为完全一样，只有控制台语言不同。各自独立放一个文件夹，整个文件夹拷到哪都能用：

| 版本 | 文件夹 | 入口 | 逻辑 |
| --- | --- | --- | --- |
| 中文 | `zh/` | `cf-tunnel-zh.cmd` | `cf-tunnel-zh.ps1` |
| English | `en/` | `cf-tunnel-en.cmd` | `cf-tunnel-en.ps1` |

`.cmd` 是双击入口（转发给 PowerShell，所以不用改执行策略）。两个 `.ps1` 都兼容 Windows PowerShell 5.1 与 PowerShell 7。

## 许可

MIT
