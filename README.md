# Peach Code Launcher

Peach Code 一键安装器。用户复制一条命令后，安装器会自动安装或刷新全局 `peach-code` 管理菜单，写入 Peach Code 中转站配置，并在缺少 Claude Code CLI / Codex CLI 时自动补齐。

当前安装器版本：`0.5.5`

## 一键安装

macOS、Linux、WSL：

```bash
curl -fsSL https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.sh | bash
```

Windows PowerShell：

```powershell
irm "https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.ps1?v=0.5.5" | iex
```

Windows CMD：

```bat
curl -fsSL -o "%TEMP%\peach-code-install.cmd" "https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.cmd?v=0.5.5" && "%TEMP%\peach-code-install.cmd"
```

注意：`curl ... install.sh | bash` 只适用于 macOS、Linux、WSL，不适用于 Windows CMD。如果在 CMD 里看到 `'bash' 不是内部或外部命令`，请改用上面的 Windows CMD 命令。

安装过程中用户会看到三步引导：

1. 选择 Peach Code 线路。
2. 自动打开 API Key 页面。
3. 在 terminal 里粘贴 API Key。

API Key 页面：

```text
https://cli.rhinelab.com.cn/keys
```

## 安装器会做什么

Peach Code 支持两条线路：

- 主线路：`https://cli.rhinelab.com.cn`
- CMIN2 直连线路：`https://cli-speed.rhinelab.com.cn`

安装器会写入这些内容：

- Claude Code 配置：`~/.claude/settings.json`
- Codex 配置：`~/.codex/config.toml`
- Peach Code API Key：`~/.peach-code/api_key`
- 管理命令：`peach-code`

如果检测到 `claude` 和 `codex` 都已经安装，安装器会跳过 Node.js/npm 检查和官方 CLI 安装器，只刷新 `peach-code` 管理脚本、写入 Peach Code 配置，并继续 API Key 引导。

如果缺少其中任意一个 CLI，安装器会先确保 Node.js 18+ 和 npm 可用，然后只安装缺失的 CLI：

- 已安装 `claude`、缺少 `codex`：只安装 Codex CLI。
- 已安装 `codex`、缺少 `claude`：只安装 Claude Code CLI。
- 两个都缺少：两个都安装。

## Node.js 依赖兜底

Claude Code CLI 依赖 Node.js/npm。为了让小白用户尽量少处理环境问题，安装器会按以下顺序处理 Node.js：

macOS/Linux：

1. 使用已有的 Node.js 18+ 和 npm。
2. 使用已有的 Peach Code 内置 runtime。
3. 从 GitHub Release 下载 Peach Code 镜像的便携 Node.js runtime。
4. 尝试 Homebrew、apt、dnf、yum、pacman、apk、zypper。
5. 最后尝试 nvm。

Windows：

1. 使用已有的 Node.js 18+ 和 npm。
2. 使用已有的 Peach Code 内置 runtime。
3. 从 GitHub Release 下载 Peach Code 镜像的便携 Node.js runtime。
4. 尝试 winget、Chocolatey、Scoop。

如果 Claude/Codex 官方 PowerShell 安装器返回了网页 HTML 或执行失败，安装器会自动 fallback 到 npm 安装：

```text
@anthropic-ai/claude-code@latest
@openai/codex@latest
```

## 自动日志和自检

Windows 安装器会自动开启日志，并在安装结尾运行自检。自检会检查：

- `peach-code` 管理命令是否写入并进入 PATH。
- Claude/Codex 命令是否可执行。
- Claude `settings.json` 和 Codex `config.toml` 是否写入 Peach Code provider。
- endpoint、API Key helper、API Key 文件是否处于预期状态。
- Node.js runtime 下载失败时的 URL、文件大小、SHA256、content-type 和文件开头预览。

默认日志位置：

```text
~\.peach-code\logs\install-YYYYMMDD-HHMMSS.log
```

如果 CMD bootstrap 在进入安装器前就失败，还会在 `%TEMP%` 下生成：

```text
peach-code-bootstrap-YYYYMMDD-HHMMSS.log
```

安装失败时，把终端显示的日志路径对应文件发给支持即可；日志不会打印 API Key 内容。

内置 runtime 安装目录：

```text
~/.peach-code/runtime/node
```

对应 GitHub Release：

```text
https://github.com/yellowpeachxgp/peach-code-launcher/releases/tag/node-runtime-v24.16.0
```

## 安装后的命令

安装完成后，用户可以在任意目录运行：

```bash
peach-code
peach-code keys
peach-code auth
peach-code endpoint
peach-code doctor
peach-code update
```

命令说明：

- `peach-code`：打开交互式管理菜单。
- `peach-code keys`：打开 Peach Code API Key 页面。
- `peach-code auth`：输入或更新本地 API Key。
- `peach-code endpoint`：切换主线路 / CMIN2 直连线路。
- `peach-code endpoint primary`：切换到主线路。
- `peach-code endpoint speed`：切换到 CMIN2 直连线路。
- `peach-code configure`：重新写入 Claude/Codex 配置。
- `peach-code doctor`：检查 CLI、配置、线路和 key 状态，不会打印 key 内容。
- `peach-code update`：从 GitHub 检查并自动执行新版安装器。
- `peach-code update --check`：只检查版本，不安装。
- `peach-code version`：显示当前管理脚本版本。

## 配置写入示例

Codex 会被配置成独立 provider：

```toml
model_provider = "peach"

[model_providers.peach]
name = "Peach Code API"
base_url = "https://cli.rhinelab.com.cn/v1"
wire_api = "responses"

[model_providers.peach.auth]
command = "/Users/example/.peach-code/bin/peach-api-key"
refresh_interval_ms = 0
```

Claude Code 会写入官方 gateway 配置：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://cli.rhinelab.com.cn",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1"
  },
  "apiKeyHelper": "/Users/example/.peach-code/bin/peach-api-key"
}
```

API Key 不会直接写进 JSON/TOML。安装器会把 key 保存到：

```text
~/.peach-code/api_key
```

macOS/Linux 下该文件权限会设置为 `600`。

## 环境变量

| 变量 | 作用 |
| --- | --- |
| `PEACH_CODE_ENDPOINT` | 跳过线路选择，直接指定 endpoint。 |
| `PEACH_CODE_INSTALL_URL` | 指定 `peach-code update` 使用的安装脚本 URL。 |
| `PEACH_CODE_COMMAND_DIR` | 指定 `peach-code` 命令 shim 的安装目录。 |
| `PEACH_CODE_NO_BROWSER=1` | 不自动打开浏览器。适合 SSH、CI、无桌面环境。 |
| `PEACH_CODE_NODE_RUNTIME_BASE_URL` | 指定 Node.js runtime 镜像资产的 URL 前缀。 |
| `PEACH_CODE_LOG_DIR` | 指定 Windows 安装日志目录。 |
| `PEACH_CODE_NO_LOG=1` | 关闭 Windows 安装器 transcript 日志。 |
| `PEACH_CODE_VERBOSE_LOG=1` | 将诊断行同时输出到 terminal。 |
| `PEACH_CODE_SKIP_NODE=1` | 跳过 Node.js/npm 前置检查。仅建议高级用户使用。 |
| `PEACH_CODE_SKIP_AUTH=1` | 跳过 API Key 输入。稍后可运行 `peach-code auth`。 |
| `PEACH_CODE_DRY_RUN=1` | 本地测试模式，跳过官方 CLI 安装器和最终 CLI 验证。 |
| `PEACH_CODE_NON_INTERACTIVE=1` | 非交互模式，默认使用主线路。 |

示例：

```bash
PEACH_CODE_NO_BROWSER=1 curl -fsSL https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.sh | bash
```

```bash
PEACH_CODE_ENDPOINT=https://cli-speed.rhinelab.com.cn curl -fsSL https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.sh | bash
```

## 本地验证

运行 smoke test：

```bash
bash tests/smoke.sh
```

这个测试会覆盖：

- `install.sh` 语法检查。
- dry-run 安装流程。
- `peach-code doctor` / `keys` / `auth`。
- 已有 `claude` 和 `codex` 时只刷新 `peach-code` 的路径。
- Node.js runtime PATH 写入。

手动 dry-run：

```bash
tmp_home="$(mktemp -d)"
cmd_dir="$(mktemp -d)"

HOME="$tmp_home" \
PEACH_CODE_COMMAND_DIR="$cmd_dir" \
PEACH_CODE_DRY_RUN=1 \
PEACH_CODE_SKIP_NODE=1 \
PEACH_CODE_NON_INTERACTIVE=1 \
PEACH_CODE_SKIP_AUTH=1 \
bash install.sh

HOME="$tmp_home" PATH="$cmd_dir:$PATH" peach-code doctor
```

## 维护 Node.js Runtime 镜像

不要把 Node.js 二进制资产提交到 git。便携 runtime 放在 GitHub Release assets。

重新镜像当前版本：

```bash
bash scripts/mirror-node-runtime.sh
```

脚本会：

1. 从 Node.js 官方下载 `v24.16.0` 的便携资产。
2. 使用官方 `SHASUMS256.txt` 校验。
3. 生成 `node-manifest.json`。
4. 在 `node-runtime-v24.16.0` GitHub Release 上传或覆盖资产。

如果要使用自己的 runtime 资产地址，需要保持文件名一致，例如：

```text
node-v24.16.0-darwin-arm64.tar.xz
node-v24.16.0-darwin-x64.tar.xz
node-v24.16.0-linux-arm64.tar.xz
node-v24.16.0-linux-x64.tar.xz
node-v24.16.0-win-arm64.zip
node-v24.16.0-win-x64.zip
```

然后设置：

```bash
PEACH_CODE_NODE_RUNTIME_BASE_URL=https://example.com/node-runtime curl -fsSL https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.sh | bash
```

## 运维注意

- 站点品牌是 Peach Code；`rhinelab.com.cn` 只是域名。
- 默认 provider ID 是 `peach`。
- 现有 Claude/Codex 配置文件会在修改前备份。
- Codex 顶层 `model_provider` 会被设置为 `peach`，这是预期行为。
- 用户换 key 时运行 `peach-code auth`。
- 用户换线路时运行 `peach-code endpoint`。
- 用户更新安装器时运行 `peach-code update`。
- 排错文档见 [`docs/troubleshooting.md`](docs/troubleshooting.md)。
