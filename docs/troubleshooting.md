# Troubleshooting

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
