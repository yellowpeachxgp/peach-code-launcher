# Troubleshooting

## `peach-code` Command Not Found

Close and reopen the terminal. The installer adds the Peach Code bin directory to the shell profile or user PATH.

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

The key page is:

```text
https://cli.rhinelab.com.cn/keys
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
