# Peach Code Launcher

One-click installer for Peach Code users. Users copy one command, the script installs or refreshes the global `peach-code` terminal menu, writes Peach Code as the default gateway/provider, and installs Claude Code CLI / Codex CLI only when they are missing.

## What It Configures

Peach Code has two endpoints:

- Main: `https://cli.rhinelab.com.cn`
- CMIN2 direct: `https://cli-speed.rhinelab.com.cn`

The installer writes:

- Claude Code user settings: `~/.claude/settings.json`
- Codex user config: `~/.codex/config.toml`
- Peach Code API key: `~/.peach-code/api_key`
- Terminal manager: `peach-code`

On macOS/Linux, the installer places a `peach-code` command shim in `/usr/local/bin` when possible, then falls back to `~/.local/bin` and updates the user's shell profile. On Windows, it installs `peach-code.cmd` under `~/.peach-code/bin` and adds that directory to the user PATH.

When both `claude` and `codex` are already installed, the installer skips Node.js/npm checks and official CLI installers, then only refreshes `peach-code` and Peach Code config. If either CLI is missing, the installer verifies Node.js 18+ and npm first. If the machine does not already have a usable Node.js, it first tries Peach Code's mirrored portable Node.js runtime from this repository's GitHub Releases, then falls back to system package managers:

- macOS/Linux: existing Node.js 18+ and npm, existing Peach Code runtime, GitHub Release runtime, Homebrew/apt/dnf/yum/pacman/apk/zypper, then nvm fallback.
- Windows: existing Node.js 18+ and npm, existing Peach Code runtime, GitHub Release runtime, winget, Chocolatey, then Scoop.

The mirrored runtime is installed under `~/.peach-code/runtime/node`. On macOS/Linux, the installer adds its `bin` directory to the user's shell profile when that runtime is used. On Windows, the installer adds the runtime directory to the user PATH.

Set `PEACH_CODE_SKIP_NODE=1` only when you intentionally want to skip this dependency preflight.

Codex is configured as an explicit provider:

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

Claude is configured through its official gateway settings:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://cli.rhinelab.com.cn",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1"
  },
  "apiKeyHelper": "/Users/example/.peach-code/bin/peach-api-key"
}
```

## User Install Commands

macOS, Linux, or WSL:

```bash
curl -fsSL https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.ps1 | iex
```

Users will be prompted to:

1. Choose the main or CMIN2 direct endpoint.
2. Let the installer open `https://cli.rhinelab.com.cn/keys` in the browser.
3. Paste their Peach Code API key back into the terminal.

After that, users can run `peach-code` from any working directory to open the management menu.

## Management Command

After installation, users can run:

```bash
peach-code
peach-code keys
peach-code auth
peach-code endpoint
peach-code doctor
peach-code update
```

Commands:

- `peach-code`: open the interactive management menu.
- `peach-code keys`: open the Peach Code API key page in the default browser.
- `peach-code auth`: enter or replace the local API key.
- `peach-code endpoint`: switch between main and CMIN2 direct endpoints.
- `peach-code doctor`: inspect CLI, config, endpoint, and key status without printing the key.
- `peach-code update`: check GitHub for a newer installer and run it automatically.
- `peach-code update --check`: check only.

## Local Smoke Test

Run without touching your real home directory:

```bash
tmp_home="$(mktemp -d)"
HOME="$tmp_home" \
PEACH_CODE_DRY_RUN=1 \
PEACH_CODE_NON_INTERACTIVE=1 \
PEACH_CODE_SKIP_AUTH=1 \
bash install.sh

HOME="$tmp_home" "$tmp_home/.peach-code/bin/peach-code" doctor
```

## Notes For Operators

- Keep API keys out of the JSON/TOML config files. The installer stores the key in `~/.peach-code/api_key` with file mode `600`.
- Existing Claude/Codex config files are backed up before edits.
- Existing Codex config is preserved where possible, but the top-level `model_provider` is changed to `peach` by design.
- If users need to rotate keys, tell them to run `peach-code auth`.
- If users are on SSH, CI, or a browserless machine, set `PEACH_CODE_NO_BROWSER=1` to skip automatic browser opening.
- If users already manage Node.js themselves, they can set `PEACH_CODE_SKIP_NODE=1`, but the default path checks Node/npm for small-user friendliness.
- If you need to mirror Node.js runtime assets again, run `scripts/mirror-node-runtime.sh`. It downloads official Node.js portable archives, verifies `SHASUMS256.txt`, writes `node-manifest.json`, and uploads the assets to the `node-runtime-v24.16.0` GitHub Release when `gh` is authenticated.
- To host runtime assets elsewhere, set `PEACH_CODE_NODE_RUNTIME_BASE_URL` to a URL prefix containing the same asset filenames, for example `node-v24.16.0-darwin-arm64.tar.xz`.
