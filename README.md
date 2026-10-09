# Cloudflare 一键隧道

[English](README.en.md) ｜ **中文**

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

## 安全提醒

**你隧道出去的，就是公开的。** 快速隧道会把你本机的服务暴露到整个互联网，而那个随机地址**不是密码**——任何人拿到它就能访问你的服务，前面没有任何登录页。

- 别把地址发到群里、论坛或任何公开地方——它有效期间等同于一个临时密码。
- 不要拿它暴露敏感服务：管理后台、数据库、文件共享、类远程桌面、以及任何自身没有认证的服务。需要访问控制就做在服务里（或改用命名隧道 + Cloudflare Access）。
- 本地服务尽量只监听 `127.0.0.1`（默认就是）。如果它监听在 `0.0.0.0` 上，那在本工具还没上场之前，同局域网的人就已经能访问了。
- 流量在 Cloudflare 边缘节点会被解密，再加密送到你机器上。不要把不愿交给第三方的数据往里塞。
- 地址是一次性的：用完按 `Ctrl + C`。下次运行会换新地址，旧地址随即失效。
- 不要用它做违反 Cloudflare 条款或当地法律的事。

**关于下载源。** 首次运行会下载 `cloudflared.exe`。因为部分网络访问 GitHub 慢或不通，脚本会先探测几个 GitHub 镜像（`gh-proxy.com` / `ghproxy.net` / `ghfast.top` / `github.moeyy.xyz`），取最快的下载，最后兜底 `winget`。镜像属于第三方，如果你在意供应链风险，可以对照 Cloudflare 官方公布的校验值验证文件：

```bat
certutil -hashfile "%LOCALAPPDATA%\cf-tunnel\bin\cloudflared.exe" SHA256
```

或者自己从 <https://github.com/cloudflare/cloudflared/releases> 下载放进 `PATH`——脚本优先用已有的 `cloudflared`，找不到才会下载。

**权限。** 不需要管理员权限。程序装在 `%LOCALAPPDATA%\cf-tunnel\bin\`，不改 `PATH`、不写注册表、不碰系统目录。

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

两个版本的代码完全一样，区别只在注释和提示语：中文版的注释也是中文，方便对着读；英文版注释是英文。

## 许可

MIT
