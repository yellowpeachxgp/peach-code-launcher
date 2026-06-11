# Peach Code Launcher

One-click installer for Peach Code users. It installs Claude Code CLI and Codex CLI, writes Peach Code as the default gateway/provider, then asks the user to paste a Peach Code API key in the terminal.

## What It Configures

Peach Code has two endpoints:

- Main: `https://cli.rhinelab.com.cn`
- CMIN2 direct: `https://cli-speed.rhinelab.com.cn`

The installer writes:

- Claude Code user settings: `~/.claude/settings.json`
- Codex user config: `~/.codex/config.toml`
- Peach Code API key: `~/.peach-code/api_key`
- Terminal manager: `peach-code`

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
2. Open `https://cli.rhinelab.com.cn/keys`.
3. Paste their Peach Code API key.

## Management Command

After installation, users can run:

```bash
peach-code auth
peach-code endpoint
peach-code doctor
peach-code update
```

Commands:

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
