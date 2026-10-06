@echo off
chcp 65001 >nul
setlocal
title Cloudflare One-Click Tunnel
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cf-tunnel-en.ps1" %*
if errorlevel 1 (
  echo.
  echo [!] Script exited with an error.
  pause
)
endlocal
