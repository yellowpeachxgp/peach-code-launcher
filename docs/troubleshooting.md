# Troubleshooting

## Windows CMD Shows `'bash' Is Not Recognized`

`curl ... install.sh | bash` is only for macOS, Linux, or WSL. Windows CMD does not include Bash by default.

Use the CMD bootstrap command instead:

```bat
curl -fsSL -o "%TEMP%\peach-code-install.cmd" https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.cmd && "%TEMP%\peach-code-install.cmd"
```

Or use PowerShell:

```powershell
irm https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.ps1 | iex
```

## `peach-code` Command Not Found

Close and reopen the terminal.

On macOS/Linux, the installer first tries to install `peach-code` into `/usr/local/bin`. If it cannot write there, it installs into `~/.local/bin` and updates the shell profile. On Windows, it adds `~/.peach-code\bin` to the user PATH.

macOS/Linux temporary fix:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Windows temporary fix:

```powershell
$env:Path += ";$HOME\.peach-code\bin"
```

## Wrong Endpoint

Run:

```bash
peach-code endpoint
```

Or switch directly:

```bash
peach-code endpoint primary
peach-code endpoint speed
```

## Wrong Or Expired API Key

Run:

```bash
peach-code auth
```

The command tries to open the key page in the default browser. If the browser does not open automatically, copy the printed URL manually.

The key page is:

```text
https://cli.rhinelab.com.cn/keys
```

For SSH, CI, or browserless environments:

```bash
PEACH_CODE_NO_BROWSER=1 peach-code auth
```

## Node.js Or npm Problems

The installer checks for Node.js 18+ and npm before it runs any missing Claude/Codex official installer. If both `claude` and `codex` are already installed, it skips this preflight and only refreshes `peach-code` plus the Peach Code config.

If a PowerShell installer downloads HTML instead of a script, the launcher detects that and falls back to npm for the missing CLI.

If Node.js is missing, the installer first tries to download Peach Code's mirrored portable Node.js runtime from GitHub Releases. The runtime is installed under:

```text
~/.peach-code/runtime/node
```

On macOS/Linux, the runtime `bin` directory is added to the user's shell profile. On Windows, the runtime directory is added to the user PATH. Close and reopen the terminal after installation if `node`, `claude`, or `codex` cannot be found.

If automatic installation fails, install Node.js LTS manually:

```text
https://nodejs.org/
```

Then verify:

```bash
node -v
npm -v
```

Advanced users who already manage Node.js can skip the preflight:

```bash
PEACH_CODE_SKIP_NODE=1 curl -fsSL https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.sh | bash
```

Operators can override the mirrored runtime location:

```bash
PEACH_CODE_NODE_RUNTIME_BASE_URL=https://example.com/node-runtime curl -fsSL https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.sh | bash
```

## Check The Installation

Run:

```bash
peach-code doctor
```

It checks:

- whether `claude`, `codex`, and `curl` are available
- which Peach Code endpoint is active
- whether an API key file exists
- whether Claude and Codex config files contain Peach Code settings

It does not print the API key.

## Update The Installer

Run:

```bash
peach-code update --check
peach-code update
```

If update cannot reach GitHub, check that the machine can access `raw.githubusercontent.com`, then run `peach-code update --check` again.
