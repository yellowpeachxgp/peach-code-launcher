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

assert_contains install.sh 'PEACH_CODE_VERSION="0.4.0"'
assert_contains install.sh 'ensure_node_runtime'
assert_contains install.sh 'PEACH_CODE_SKIP_NODE=1'
assert_order install.sh 'ensure_node_runtime' 'curl -fsSL https://claude.ai/install.sh | bash'

assert_contains install.ps1 '$PeachCodeVersion = "0.4.0"'
assert_contains install.ps1 'Ensure-NodeRuntime'
assert_contains install.ps1 'PEACH_CODE_SKIP_NODE'
assert_order install.ps1 'Ensure-NodeRuntime' 'Invoke-WebRequest -UseBasicParsing -Uri "https://claude.ai/install.ps1"'

tmp_home="$(mktemp -d)"
cmd_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_home" "$cmd_dir"' EXIT

HOME="$tmp_home" \
  PEACH_CODE_COMMAND_DIR="$cmd_dir" \
  PEACH_CODE_DRY_RUN=1 \
  PEACH_CODE_SKIP_NODE=1 \
  PEACH_CODE_NON_INTERACTIVE=1 \
  PEACH_CODE_SKIP_AUTH=1 \
  PEACH_CODE_NO_BROWSER=1 \
  bash install.sh >/tmp/peach-code-smoke-install.log 2>&1

HOME="$tmp_home" PATH="$cmd_dir:$PATH" peach-code doctor >/tmp/peach-code-smoke-doctor.log
HOME="$tmp_home" PATH="$cmd_dir:$PATH" PEACH_CODE_NO_BROWSER=1 peach-code keys >/tmp/peach-code-smoke-keys.log 2>&1
printf 'pc-smoke-key\n' | HOME="$tmp_home" PATH="$cmd_dir:$PATH" PEACH_CODE_NO_BROWSER=1 peach-code auth >/tmp/peach-code-smoke-auth.log 2>&1

assert_contains /tmp/peach-code-smoke-install.log 'Peach Code 安装器 0.4.0'
assert_contains /tmp/peach-code-smoke-install.log 'DRY RUN: 跳过 Node.js/npm 前置依赖检查。'
assert_contains /tmp/peach-code-smoke-doctor.log 'Claude config: ok'
assert_contains /tmp/peach-code-smoke-doctor.log 'Codex config: ok'
assert_contains /tmp/peach-code-smoke-keys.log 'API Key 页面：https://cli.rhinelab.com.cn/keys'
assert_contains /tmp/peach-code-smoke-auth.log 'API Key 已保存'

printf 'smoke ok\n'
