@echo off
setlocal EnableExtensions

set "PEACH_CODE_INSTALL_PS1=https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-RestMethod -Uri '%PEACH_CODE_INSTALL_PS1%' | Invoke-Expression } catch { Write-Error $_; exit 1 }"
exit /b %ERRORLEVEL%
