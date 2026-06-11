$ErrorActionPreference = "Stop"

$PeachCodeVersion = "0.1.0"
$BrandName = "Peach Code"
$ProviderId = "peach"
$PrimaryEndpoint = "https://cli.rhinelab.com.cn"
$SpeedEndpoint = "https://cli-speed.rhinelab.com.cn"
$KeyUrl = "https://cli.rhinelab.com.cn/keys"
$DefaultInstallUrl = if ($env:PEACH_CODE_INSTALL_URL) { $env:PEACH_CODE_INSTALL_URL } else { "https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.ps1" }

$StateDir = if ($env:PEACH_CODE_HOME) { $env:PEACH_CODE_HOME } else { Join-Path $HOME ".peach-code" }
$BinDir = Join-Path $StateDir "bin"
$ApiKeyFile = Join-Path $StateDir "api_key"
$EndpointFile = Join-Path $StateDir "endpoint"
$InstallUrlFile = Join-Path $StateDir "install_url"
$Helper = Join-Path $BinDir "peach-api-key.ps1"
$HelperCmd = Join-Path $BinDir "peach-api-key.cmd"
$Manager = Join-Path $BinDir "peach-code.ps1"
$ManagerCmd = Join-Path $BinDir "peach-code.cmd"

function Write-Info($Message) {
  Write-Host "==> $Message" -ForegroundColor Blue
}

function Write-Warn($Message) {
  Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Normalize-Endpoint($Endpoint) {
  return $Endpoint.TrimEnd("/")
}

function Select-PeachEndpoint {
  if ($env:PEACH_CODE_ENDPOINT) {
    return Normalize-Endpoint $env:PEACH_CODE_ENDPOINT
  }

  if ($env:PEACH_CODE_NON_INTERACTIVE -eq "1") {
    return $PrimaryEndpoint
  }

  Write-Host ""
  Write-Host "请选择 Peach Code 线路："
  Write-Host "  1) 主线路       $PrimaryEndpoint"
  Write-Host "  2) CMIN2 直连   $SpeedEndpoint"
  $choice = Read-Host "选择 [1/2]，直接回车默认主线路"

  switch ($choice) {
    "2" { return $SpeedEndpoint }
    default { return $PrimaryEndpoint }
  }
}

function Add-BinToUserPath {
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $userPath) { $userPath = "" }
  $parts = $userPath -split ";" | Where-Object { $_ }
  if ($parts -notcontains $BinDir) {
    $newPath = if ($userPath) { "$userPath;$BinDir" } else { $BinDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$env:Path;$BinDir"
    Write-Info "已将 $BinDir 加入用户 PATH。新终端会自动生效。"
  }
}

function Write-Manager {
  New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

  $managerContent = @'
$ErrorActionPreference = "Stop"

$PeachCodeVersion = "0.1.0"
$ProviderId = "peach"
$PrimaryEndpoint = "https://cli.rhinelab.com.cn"
$SpeedEndpoint = "https://cli-speed.rhinelab.com.cn"
$KeyUrl = "https://cli.rhinelab.com.cn/keys"
$DefaultInstallUrl = "https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.ps1"

$StateDir = if ($env:PEACH_CODE_HOME) { $env:PEACH_CODE_HOME } else { Join-Path $HOME ".peach-code" }
$BinDir = Join-Path $StateDir "bin"
$ApiKeyFile = Join-Path $StateDir "api_key"
$EndpointFile = Join-Path $StateDir "endpoint"
$InstallUrlFile = Join-Path $StateDir "install_url"
$Helper = Join-Path $BinDir "peach-api-key.ps1"
$HelperCmd = Join-Path $BinDir "peach-api-key.cmd"

function Write-Info($Message) {
  Write-Host "==> $Message" -ForegroundColor Blue
}

function Write-Warn($Message) {
  Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Normalize-Endpoint($Endpoint) {
  return $Endpoint.TrimEnd("/")
}

function Get-CurrentEndpoint {
  if (Test-Path $EndpointFile) {
    $value = (Get-Content -Raw -Path $EndpointFile).Trim()
    if ($value) { return Normalize-Endpoint $value }
  }
  return $PrimaryEndpoint
}

function Get-InstallUrl {
  if (Test-Path $InstallUrlFile) {
    $value = (Get-Content -Raw -Path $InstallUrlFile).Trim()
    if ($value) { return $value }
  }
  if ($env:PEACH_CODE_INSTALL_URL) { return $env:PEACH_CODE_INSTALL_URL }
  return $DefaultInstallUrl
}

function Write-Helper {
  New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

  @(
    '$ErrorActionPreference = "Stop"',
    '$keyFile = if ($env:PEACH_CODE_HOME) { Join-Path $env:PEACH_CODE_HOME "api_key" } else { Join-Path $HOME ".peach-code\api_key" }',
    'if (-not (Test-Path $keyFile)) {',
    '  Write-Error "Peach Code API key is missing. Run: peach-code auth"',
    '  exit 1',
    '}',
    '(Get-Content -Raw -Path $keyFile).Trim()'
  ) | Set-Content -Encoding UTF8 -Path $Helper

  @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "$Helper" %*
"@ | Set-Content -Encoding ASCII -Path $HelperCmd
}

function Convert-ObjectToHashtable($Value) {
  if ($null -eq $Value) {
    return @{}
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $table = @{}
    foreach ($key in $Value.Keys) {
      $table[$key] = $Value[$key]
    }
    return $table
  }

  if ($Value -is [pscustomobject]) {
    $table = @{}
    foreach ($prop in $Value.PSObject.Properties) {
      $table[$prop.Name] = $prop.Value
    }
    return $table
  }

  return @{}
}

function Set-ClaudeSettings($Endpoint) {
  $settingsDir = Join-Path $HOME ".claude"
  $settingsFile = Join-Path $settingsDir "settings.json"
  New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null

  $data = [ordered]@{}
  if (Test-Path $settingsFile) {
    try {
      $existing = Get-Content -Raw -Path $settingsFile | ConvertFrom-Json
      if ($existing) {
        foreach ($prop in $existing.PSObject.Properties) {
          $data[$prop.Name] = $prop.Value
        }
      }
    } catch {
      Copy-Item $settingsFile "$settingsFile.peach-backup.$(Get-Date -Format yyyyMMddHHmmss)" -Force
      $data = [ordered]@{}
    }
  }

  if (-not $data.Contains('$schema')) {
    $data['$schema'] = "https://json.schemastore.org/claude-code-settings.json"
  }

  $envTable = Convert-ObjectToHashtable $data['env']

  $envTable['ANTHROPIC_BASE_URL'] = $Endpoint
  $envTable['CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY'] = "1"
  $data['env'] = $envTable
  $data['apiKeyHelper'] = $HelperCmd

  $data | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 -Path $settingsFile
}

function Set-CodexConfig($Endpoint) {
  $codexDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
  $configFile = Join-Path $codexDir "config.toml"
  New-Item -ItemType Directory -Force -Path $codexDir | Out-Null

  if (Test-Path $configFile) {
    Copy-Item $configFile "$configFile.peach-backup.$(Get-Date -Format yyyyMMddHHmmss)" -Force
    $lines = Get-Content -Path $configFile
  } else {
    $lines = @()
  }

  $filtered = New-Object System.Collections.Generic.List[string]
  $table = "root"
  $skipPeach = $false
  $skipManaged = $false

  foreach ($line in $lines) {
    if ($line -match '^\s*# BEGIN Peach Code managed\s*$') { $skipManaged = $true; continue }
    if ($line -match '^\s*# END Peach Code managed\s*$') { $skipManaged = $false; continue }
    if ($skipManaged) { continue }

    if ($line -match '^\s*\[') {
      if ($line -match '^\s*\[model_providers\.peach(\]|\.)') {
        $skipPeach = $true
        continue
      }
      $skipPeach = $false
      $table = $line.Trim()
    }

    if ($skipPeach) { continue }
    if ($table -eq "root" -and $line -match '^\s*model_provider\s*=') { continue }

    $filtered.Add($line)
  }

  $baseUrl = (Normalize-Endpoint $Endpoint) + "/v1"
  $escapedHelper = $HelperCmd.Replace('\', '\\').Replace('"', '\"')

  $managed = @"

# BEGIN Peach Code managed
model_provider = "peach"

[model_providers.peach]
name = "Peach Code API"
base_url = "$baseUrl"
wire_api = "responses"

[model_providers.peach.auth]
command = "$escapedHelper"
refresh_interval_ms = 0
# END Peach Code managed
"@

  ($filtered -join "`n") + $managed + "`n" | Set-Content -Encoding UTF8 -Path $configFile
}

function Configure-Peach {
  param([string]$Endpoint = "")
  if (-not $Endpoint) { $Endpoint = Get-CurrentEndpoint }
  $Endpoint = Normalize-Endpoint $Endpoint

  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  $Endpoint | Set-Content -Encoding ASCII -Path $EndpointFile
  Write-Helper
  Set-ClaudeSettings $Endpoint
  Set-CodexConfig $Endpoint

  Write-Info "已写入 Peach Code 配置：$Endpoint"
}

function Set-PeachAuth {
  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  Write-Host ""
  Write-Host "请打开 Peach Code 获取 API Key："
  Write-Host $KeyUrl
  Write-Host ""
  $secure = Read-Host "请粘贴 API Key" -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
  if (-not $apiKey) { throw "API Key 不能为空。" }
  $apiKey | Set-Content -Encoding ASCII -NoNewline -Path $ApiKeyFile
  Write-Info "API Key 已保存到 $ApiKeyFile"
}

function Set-PeachEndpoint {
  param([string]$Choice = "")
  switch ($Choice) {
    "primary" { Configure-Peach $PrimaryEndpoint; return }
    "speed" { Configure-Peach $SpeedEndpoint; return }
    { $_ -match '^https?://' } { Configure-Peach $Choice; return }
    "" {
      Write-Host ""
      Write-Host "当前线路：$(Get-CurrentEndpoint)"
      Write-Host ""
      Write-Host "请选择 Peach Code 线路："
      Write-Host "  1) 主线路       $PrimaryEndpoint"
      Write-Host "  2) CMIN2 直连   $SpeedEndpoint"
      $selection = Read-Host "选择 [1/2]"
      if ($selection -eq "2") { Configure-Peach $SpeedEndpoint } else { Configure-Peach $PrimaryEndpoint }
      return
    }
    default { throw "Usage: peach-code endpoint [primary|speed|https://custom.example.com]" }
  }
}

function Invoke-PeachDoctor {
  Write-Host "Peach Code manager: $PeachCodeVersion"
  Write-Host "Endpoint: $(Get-CurrentEndpoint)"
  if (Test-Path $ApiKeyFile) {
    Write-Host "Key file: $ApiKeyFile (exists)"
  } else {
    Write-Host "Key file: $ApiKeyFile (missing)"
  }

  foreach ($cmd in @("claude", "codex", "curl")) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) { Write-Host "$cmd: $($found.Source)" } else { Write-Host "${cmd}: missing" }
  }

  $claudeSettings = Join-Path $HOME ".claude\settings.json"
  $codexConfig = if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "config.toml" } else { Join-Path $HOME ".codex\config.toml" }
  if ((Test-Path $claudeSettings) -and ((Get-Content -Raw $claudeSettings) -match 'ANTHROPIC_BASE_URL')) {
    Write-Host "Claude config: ok"
  } else {
    Write-Host "Claude config: missing Peach Code base URL"
  }
  if ((Test-Path $codexConfig) -and ((Get-Content -Raw $codexConfig) -match '\[model_providers\.peach\]')) {
    Write-Host "Codex config: ok"
  } else {
    Write-Host "Codex config: missing Peach Code provider"
  }
}

function Get-InstallerVersion($Path) {
  $line = Get-Content -Path $Path | Where-Object { $_ -match '^\$PeachCodeVersion\s*=' } | Select-Object -First 1
  if ($line -match '"([^"]+)"') { return $Matches[1] }
  return ""
}

function Update-Peach {
  param([switch]$Check, [switch]$Force)
  $url = Get-InstallUrl
  $tmp = Join-Path $env:TEMP "peach-code-install-$([Guid]::NewGuid()).ps1"
  Write-Info "正在检查更新：$url"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmp
  $remoteVersion = Get-InstallerVersion $tmp
  if (-not $remoteVersion) { throw "无法从远程安装脚本读取版本号。" }

  if ($remoteVersion -eq $PeachCodeVersion -and -not $Force) {
    Write-Info "已经是最新版本：$PeachCodeVersion"
    Remove-Item $tmp -Force
    return
  }

  Write-Host "本地版本：$PeachCodeVersion"
  Write-Host "远程版本：$remoteVersion"
  if ($Check) {
    Remove-Item $tmp -Force
    return
  }

  Write-Info "正在自动获取并执行新版安装器..."
  $env:PEACH_CODE_INSTALL_URL = $url
  $env:PEACH_CODE_ENDPOINT = Get-CurrentEndpoint
  $env:PEACH_CODE_SKIP_AUTH = "1"
  powershell -NoProfile -ExecutionPolicy Bypass -File $tmp
  Remove-Item $tmp -Force
}

function Show-Help {
  Write-Host @"
Peach Code manager $PeachCodeVersion

Usage:
  peach-code auth                 输入或更新 Peach Code API Key
  peach-code endpoint             交互式切换主线路 / CMIN2 直连线路
  peach-code endpoint primary     切换到主线路
  peach-code endpoint speed       切换到 CMIN2 直连线路
  peach-code configure            重新写入 Claude/Codex 配置
  peach-code doctor               检查安装、配置和 key 状态
  peach-code update               检查并自动获取新版安装脚本
  peach-code update --check       只检查，不安装
  peach-code version              显示版本
"@
}

$cmd = if ($args.Count -gt 0) { $args[0] } else { "help" }
$rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

switch ($cmd) {
  "auth" { Set-PeachAuth }
  "endpoint" { Set-PeachEndpoint @rest }
  "configure" {
    $endpoint = ""
    if ($rest.Count -ge 2 -and $rest[0] -eq "--endpoint") { $endpoint = $rest[1] }
    Configure-Peach $endpoint
  }
  "doctor" { Invoke-PeachDoctor }
  "update" {
    $check = $rest -contains "--check"
    $force = $rest -contains "--force"
    Update-Peach -Check:$check -Force:$force
  }
  "version" { Write-Host $PeachCodeVersion }
  "--version" { Write-Host $PeachCodeVersion }
  "verify" {
    foreach ($cmdName in @("claude", "codex")) {
      $found = Get-Command $cmdName -ErrorAction SilentlyContinue
      if ($found) { & $cmdName --version } else { Write-Warn "$cmdName 还不在 PATH 中。请重新打开终端，或确认安装输出。" }
    }
  }
  default { Show-Help }
}
'@

  $managerContent | Set-Content -Encoding UTF8 -Path $Manager

  @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "$Manager" %*
"@ | Set-Content -Encoding ASCII -Path $ManagerCmd
}

function Install-OfficialClis {
  if ($env:PEACH_CODE_DRY_RUN -eq "1") {
    Write-Info "DRY RUN: 跳过 Claude Code 和 Codex CLI 官方安装器。"
    return
  }

  Write-Info "正在安装或更新 Claude Code CLI..."
  Invoke-Expression (Invoke-WebRequest -UseBasicParsing -Uri "https://claude.ai/install.ps1").Content

  Write-Info "正在安装或更新 Codex CLI..."
  $env:CODEX_NON_INTERACTIVE = "1"
  Invoke-Expression (Invoke-WebRequest -UseBasicParsing -Uri "https://chatgpt.com/codex/install.ps1").Content
}

function Invoke-AuthIfNeeded {
  if ($env:PEACH_CODE_SKIP_AUTH -eq "1") {
    if (Test-Path $ApiKeyFile) {
      Write-Info "保留现有 API Key：$ApiKeyFile"
    } else {
      Write-Warn "已跳过 API Key 输入；稍后请运行 peach-code auth。"
    }
    return
  }

  powershell -NoProfile -ExecutionPolicy Bypass -File $Manager auth
}

function Verify-Install {
  if ($env:PEACH_CODE_DRY_RUN -eq "1") {
    Write-Info "DRY RUN: 跳过 CLI 验证。"
    return
  }

  powershell -NoProfile -ExecutionPolicy Bypass -File $Manager verify
}

if ($args.Count -gt 0 -and ($args[0] -eq "--help" -or $args[0] -eq "-h")) {
  Write-Host @"
Peach Code installer $PeachCodeVersion

Environment overrides:
  PEACH_CODE_ENDPOINT       Use a custom endpoint instead of prompting.
  PEACH_CODE_INSTALL_URL    URL used by 'peach-code update'.
  PEACH_CODE_SKIP_AUTH=1    Do not prompt for an API key.
  PEACH_CODE_DRY_RUN=1      Skip official CLI installers for local testing.
"@
  exit 0
}

$Endpoint = Normalize-Endpoint (Select-PeachEndpoint)
Write-Info "Peach Code 安装器 $PeachCodeVersion"
Write-Info "将使用端点：$Endpoint"

New-Item -ItemType Directory -Force -Path $StateDir, $BinDir | Out-Null
$DefaultInstallUrl | Set-Content -Encoding ASCII -Path $InstallUrlFile

Install-OfficialClis
Write-Manager
Add-BinToUserPath

Write-Info "先写入 Peach Code 中转站配置..."
powershell -NoProfile -ExecutionPolicy Bypass -File $Manager configure --endpoint $Endpoint

Invoke-AuthIfNeeded
Verify-Install

Write-Host ""
Write-Host "Peach Code 已配置完成。"
Write-Host ""
Write-Host "后续可直接在 terminal 运行："
Write-Host "  peach-code auth              # 更新 API Key"
Write-Host "  peach-code endpoint          # 切换线路"
Write-Host "  peach-code doctor            # 检查安装状态"
Write-Host "  peach-code update            # 检测并获取新版本脚本"
Write-Host ""
Write-Host "如果当前终端暂时找不到 peach-code，请重新打开 PowerShell。"
