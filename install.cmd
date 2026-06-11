@echo off
setlocal EnableExtensions

set "PEACH_CODE_INSTALL_PS1_API=https://api.github.com/repos/yellowpeachxgp/peach-code-launcher/contents/install.ps1?ref=main"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $api='%PEACH_CODE_INSTALL_PS1_API%'; $tmp=Join-Path $env:TEMP ('peach-code-install-{0}.ps1' -f [Guid]::NewGuid()); $log=Join-Path $env:TEMP ('peach-code-bootstrap-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss')); try { Start-Transcript -Path $log -Append -Force | Out-Null; Write-Host ('==> Peach Code CMD bootstrap log: ' + $log); Write-Host '==> Fetching latest install.ps1 through GitHub API...'; $headers=@{'User-Agent'='peach-code-installer';'Cache-Control'='no-cache'}; $r=Invoke-RestMethod -Headers $headers -Uri $api; $content=($r.content -replace '\s',''); $script=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($content)); $encoding=New-Object System.Text.UTF8Encoding -ArgumentList $false; [IO.File]::WriteAllText($tmp, $script, $encoding); Write-Host ('==> Saved installer: ' + $tmp) } catch { Write-Error $_; Write-Host ('Peach Code bootstrap log: ' + $log); exit 1 } finally { try { Stop-Transcript | Out-Null } catch {} }; powershell -NoProfile -ExecutionPolicy Bypass -File $tmp; exit $LASTEXITCODE"
exit /b %ERRORLEVEL%
