#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "$file does not contain: $needle"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    fail "$file should not contain: $needle"
  fi
}

assert_order() {
  local file="$1"
  local first="$2"
  local second="$3"
  local first_line
  local second_line

  first_line="$(grep -nF "$first" "$file" | head -n 1 | cut -d: -f1 || true)"
  second_line="$(grep -nF "$second" "$file" | head -n 1 | cut -d: -f1 || true)"

  [ -n "$first_line" ] || fail "$file missing first marker: $first"
  [ -n "$second_line" ] || fail "$file missing second marker: $second"
  [ "$first_line" -lt "$second_line" ] || fail "$first should appear before $second in $file"
}

bash -n install.sh

assert_contains install.sh 'PEACH_CODE_VERSION="0.5.3"'
assert_contains install.sh 'NODE_RUNTIME_VERSION="v24.16.0"'
assert_contains install.sh 'install_node_from_github_runtime'
assert_contains install.sh 'curl_download'
assert_contains install.sh 'run_remote_shell_installer'
assert_contains install.sh '6b144acbcfdbca75a1366100ff96e6bf6a4fe666b88a4bda7bfbd0299c82cca2'
assert_contains install.sh 'ensure_node_runtime'
assert_contains install.sh 'official_clis_installed'
assert_contains install.sh 'setup_node_runtime_shell_path'
assert_contains install.sh '@anthropic-ai/claude-code@latest'
assert_contains install.sh '@openai/codex@latest'
assert_contains install.sh 'PEACH_CODE_SKIP_NODE=1'
assert_order install.sh 'ensure_node_runtime' 'run_remote_shell_installer "https://claude.ai/install.sh" bash'
assert_order install.sh 'install_node_from_github_runtime' 'install_node_with_package_manager'

assert_contains install.ps1 '$PeachCodeVersion = "0.5.3"'
assert_contains install.ps1 '$NodeRuntimeVersion = "v24.16.0"'
assert_contains install.ps1 'Install-NodeFromGithubRuntime'
assert_contains install.ps1 'Invoke-DownloadFile'
assert_contains install.ps1 'Test-InstallerLooksLikeHtml'
assert_contains install.ps1 'Invoke-RemotePowerShellInstaller'
assert_contains install.ps1 '@anthropic-ai/claude-code@latest'
assert_contains install.ps1 '@openai/codex@latest'
assert_contains install.ps1 'Ensure-NodeRuntime'
assert_contains install.ps1 'Test-OfficialClisInstalled'
assert_contains install.ps1 'Add-NodeRuntimeToUserPath'
assert_contains install.ps1 'PEACH_CODE_SKIP_NODE'
assert_contains install.ps1 'Write-Host "${cmd}: $($found.Source)"'
assert_not_contains install.ps1 'Write-Host "$cmd:'
assert_order install.ps1 'Ensure-NodeRuntime' 'Invoke-RemotePowerShellInstaller "https://claude.ai/install.ps1"'
assert_order install.ps1 'Install-NodeFromGithubRuntime' 'Install-NodeRuntime'

assert_contains install.cmd 'install.ps1'
assert_contains install.cmd 'Invoke-RestMethod'

assert_contains scripts/mirror-node-runtime.sh 'node-runtime-v24.16.0'
assert_contains scripts/mirror-node-runtime.sh 'node-manifest.json'

tmp_home="$(mktemp -d)"
cmd_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_home" "$cmd_dir"' EXIT
mkdir -p "$tmp_home/.peach-code/runtime/node/bin"
touch "$tmp_home/.peach-code/runtime/node/bin/node"
chmod +x "$tmp_home/.peach-code/runtime/node/bin/node"

HOME="$tmp_home" \
  PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  SHELL=/bin/zsh \
  PEACH_CODE_COMMAND_DIR="$cmd_dir" \
  PEACH_CODE_DRY_RUN=1 \
  PEACH_CODE_SKIP_NODE=1 \
  PEACH_CODE_NON_INTERACTIVE=1 \
  PEACH_CODE_SKIP_AUTH=1 \
  PEACH_CODE_NO_BROWSER=1 \
  /bin/bash install.sh >/tmp/peach-code-smoke-install.log 2>&1

HOME="$tmp_home" PATH="$cmd_dir:/usr/bin:/bin:/usr/sbin:/sbin" peach-code doctor >/tmp/peach-code-smoke-doctor.log
HOME="$tmp_home" PATH="$cmd_dir:/usr/bin:/bin:/usr/sbin:/sbin" PEACH_CODE_NO_BROWSER=1 peach-code keys >/tmp/peach-code-smoke-keys.log 2>&1
printf 'pc-smoke-key\n' | HOME="$tmp_home" PATH="$cmd_dir:/usr/bin:/bin:/usr/sbin:/sbin" PEACH_CODE_NO_BROWSER=1 peach-code auth >/tmp/peach-code-smoke-auth.log 2>&1

assert_contains /tmp/peach-code-smoke-install.log 'Peach Code 安装器 0.5.3'
assert_contains /tmp/peach-code-smoke-install.log 'DRY RUN: 跳过 Node.js/npm 前置依赖检查。'
assert_contains /tmp/peach-code-smoke-doctor.log 'Claude config: ok'
assert_contains /tmp/peach-code-smoke-doctor.log 'Codex config: ok'
assert_contains /tmp/peach-code-smoke-keys.log 'API Key 页面：https://cli.rhinelab.com.cn/keys'
assert_contains /tmp/peach-code-smoke-auth.log 'API Key 已保存'
assert_contains "$tmp_home/.zshrc" 'Peach Code Node.js runtime'

installed_home="$(mktemp -d)"
installed_cmd_dir="$(mktemp -d)"
fake_bin="$(mktemp -d)"
trap 'rm -rf "$tmp_home" "$cmd_dir" "$installed_home" "$installed_cmd_dir" "$fake_bin"' EXIT

cat >"$fake_bin/claude" <<'EOF'
#!/usr/bin/env sh
printf 'claude fake 1.0\n'
EOF
cat >"$fake_bin/codex" <<'EOF'
#!/usr/bin/env sh
printf 'codex fake 1.0\n'
EOF
chmod +x "$fake_bin/claude" "$fake_bin/codex"

HOME="$installed_home" \
  PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  PEACH_CODE_COMMAND_DIR="$installed_cmd_dir" \
  PEACH_CODE_NON_INTERACTIVE=1 \
  PEACH_CODE_SKIP_AUTH=1 \
  PEACH_CODE_NO_BROWSER=1 \
  /bin/bash install.sh >/tmp/peach-code-smoke-existing-clis.log 2>&1

assert_contains /tmp/peach-code-smoke-existing-clis.log '仅安装/刷新 peach-code 管理脚本'
assert_contains /tmp/peach-code-smoke-existing-clis.log 'claude fake 1.0'
assert_contains /tmp/peach-code-smoke-existing-clis.log 'codex fake 1.0'
if grep -Fq 'Node.js/npm 前置依赖检查' /tmp/peach-code-smoke-existing-clis.log; then
  fail "existing CLI flow should skip Node.js/npm preflight"
fi
if grep -Fq 'claude.ai/install.sh' /tmp/peach-code-smoke-existing-clis.log; then
  fail "existing CLI flow should skip Claude official installer"
fi
HOME="$installed_home" PATH="$installed_cmd_dir:$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" peach-code version >/tmp/peach-code-smoke-existing-version.log
assert_contains /tmp/peach-code-smoke-existing-version.log '0.5.3'

printf 'smoke ok\n'
