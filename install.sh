#!/usr/bin/env bash
set -euo pipefail

PEACH_CODE_VERSION="0.1.0"
BRAND_NAME="Peach Code"
PROVIDER_ID="peach"
PRIMARY_ENDPOINT="https://cli.rhinelab.com.cn"
SPEED_ENDPOINT="https://cli-speed.rhinelab.com.cn"
KEY_URL="https://cli.rhinelab.com.cn/keys"
DEFAULT_INSTALL_URL="${PEACH_CODE_INSTALL_URL:-https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.sh}"

STATE_DIR="${PEACH_CODE_HOME:-$HOME/.peach-code}"
BIN_DIR="$STATE_DIR/bin"
LOCAL_BIN="${PEACH_CODE_LOCAL_BIN:-$HOME/.local/bin}"
API_KEY_FILE="$STATE_DIR/api_key"
ENDPOINT_FILE="$STATE_DIR/endpoint"
INSTALL_URL_FILE="$STATE_DIR/install_url"
HELPER="$BIN_DIR/peach-api-key"
MANAGER="$BIN_DIR/peach-code"

usage() {
  cat <<USAGE
Peach Code installer ${PEACH_CODE_VERSION}

Usage:
  bash install.sh

Environment overrides:
  PEACH_CODE_ENDPOINT       Use a custom endpoint instead of prompting.
  PEACH_CODE_INSTALL_URL    URL used by 'peach-code update'.
  PEACH_CODE_SKIP_AUTH=1    Do not prompt for an API key.
  PEACH_CODE_DRY_RUN=1      Skip official CLI installers for local testing.
USAGE
}

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

normalize_endpoint() {
  printf '%s' "$1" | sed 's#/*$##'
}

select_endpoint() {
  if [ "${PEACH_CODE_ENDPOINT:-}" ]; then
    normalize_endpoint "$PEACH_CODE_ENDPOINT"
    return
  fi

  if [ "${PEACH_CODE_NON_INTERACTIVE:-}" = "1" ] || [ ! -t 0 ]; then
    printf '%s' "$PRIMARY_ENDPOINT"
    return
  fi

  printf '\n请选择 Peach Code 线路：\n'
  printf '  1) 主线路       %s\n' "$PRIMARY_ENDPOINT"
  printf '  2) CMIN2 直连   %s\n' "$SPEED_ENDPOINT"
  printf '直接回车默认选择主线路。\n'
  printf '选择 [1/2]: '
  read -r choice || choice=""

  case "$choice" in
    2) printf '%s' "$SPEED_ENDPOINT" ;;
    1 | "") printf '%s' "$PRIMARY_ENDPOINT" ;;
    *) warn "无法识别的选择，使用主线路。"; printf '%s' "$PRIMARY_ENDPOINT" ;;
  esac
}

write_manager() {
  mkdir -p "$BIN_DIR" "$LOCAL_BIN"

  cat >"$MANAGER" <<'MANAGER'
#!/usr/bin/env bash
set -euo pipefail

PEACH_CODE_VERSION="0.1.0"
BRAND_NAME="Peach Code"
PROVIDER_ID="peach"
PRIMARY_ENDPOINT="https://cli.rhinelab.com.cn"
SPEED_ENDPOINT="https://cli-speed.rhinelab.com.cn"
KEY_URL="https://cli.rhinelab.com.cn/keys"
DEFAULT_INSTALL_URL="https://raw.githubusercontent.com/yellowpeachxgp/peach-code-launcher/main/install.sh"

STATE_DIR="${PEACH_CODE_HOME:-$HOME/.peach-code}"
BIN_DIR="$STATE_DIR/bin"
LOCAL_BIN="${PEACH_CODE_LOCAL_BIN:-$HOME/.local/bin}"
API_KEY_FILE="$STATE_DIR/api_key"
ENDPOINT_FILE="$STATE_DIR/endpoint"
INSTALL_URL_FILE="$STATE_DIR/install_url"
HELPER="$BIN_DIR/peach-api-key"

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

normalize_endpoint() {
  printf '%s' "$1" | sed 's#/*$##'
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

toml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

current_endpoint() {
  if [ -s "$ENDPOINT_FILE" ]; then
    normalize_endpoint "$(cat "$ENDPOINT_FILE")"
  else
    printf '%s' "$PRIMARY_ENDPOINT"
  fi
}

install_url() {
  if [ -s "$INSTALL_URL_FILE" ]; then
    cat "$INSTALL_URL_FILE"
  else
    printf '%s' "${PEACH_CODE_INSTALL_URL:-$DEFAULT_INSTALL_URL}"
  fi
}

write_helper() {
  mkdir -p "$BIN_DIR" "$LOCAL_BIN"
  cat >"$HELPER" <<'HELPER'
#!/usr/bin/env sh
set -eu

key_file="${PEACH_CODE_HOME:-$HOME/.peach-code}/api_key"
if [ ! -s "$key_file" ]; then
  echo "Peach Code API key is missing. Run: peach-code auth" >&2
  exit 1
fi

cat "$key_file"
HELPER
  chmod 700 "$HELPER"

  if ln -sf "$HELPER" "$LOCAL_BIN/peach-api-key" 2>/dev/null; then
    :
  else
    cat >"$LOCAL_BIN/peach-api-key" <<EOF
#!/usr/bin/env sh
exec "$HELPER" "\$@"
EOF
    chmod 700 "$LOCAL_BIN/peach-api-key"
  fi
}

write_claude_settings() {
  endpoint="$1"
  settings_dir="$HOME/.claude"
  settings_file="$settings_dir/settings.json"
  mkdir -p "$settings_dir"

  if command -v python3 >/dev/null 2>&1; then
    SETTINGS_FILE="$settings_file" \
      CLAUDE_BASE_URL="$endpoint" \
      PEACH_HELPER="$HELPER" \
      python3 - <<'PY'
import json
import os
from pathlib import Path

settings_file = Path(os.environ["SETTINGS_FILE"])
data = {}

if settings_file.exists() and settings_file.stat().st_size:
    try:
        data = json.loads(settings_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        backup = settings_file.with_suffix(settings_file.suffix + ".peach-backup")
        backup.write_text(settings_file.read_text(encoding="utf-8"), encoding="utf-8")
        data = {}

data.setdefault("$schema", "https://json.schemastore.org/claude-code-settings.json")
env = data.get("env")
if not isinstance(env, dict):
    env = {}
env["ANTHROPIC_BASE_URL"] = os.environ["CLAUDE_BASE_URL"]
env["CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"] = "1"
data["env"] = env
data["apiKeyHelper"] = os.environ["PEACH_HELPER"]

tmp = settings_file.with_suffix(settings_file.suffix + ".tmp")
tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
tmp.replace(settings_file)
PY
  else
    if [ -f "$settings_file" ]; then
      cp "$settings_file" "$settings_file.peach-backup.$(date +%Y%m%d%H%M%S)"
    fi

    escaped_endpoint="$(json_escape "$endpoint")"
    escaped_helper="$(json_escape "$HELPER")"
    cat >"$settings_file" <<EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "ANTHROPIC_BASE_URL": "$escaped_endpoint",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1"
  },
  "apiKeyHelper": "$escaped_helper"
}
EOF
  fi
}

write_codex_config() {
  endpoint="$1"
  codex_dir="${CODEX_HOME:-$HOME/.codex}"
  config_file="$codex_dir/config.toml"
  codex_base_url="${endpoint}/v1"
  mkdir -p "$codex_dir"

  if [ -f "$config_file" ]; then
    cp "$config_file" "$config_file.peach-backup.$(date +%Y%m%d%H%M%S)"
  fi

  tmp_file="$config_file.tmp.$$"
  if [ -f "$config_file" ]; then
    awk '
      BEGIN { table="root"; skip=0; managed=0 }
      /^# BEGIN Peach Code managed$/ { managed=1; next }
      /^# END Peach Code managed$/ { managed=0; next }
      managed { next }
      /^[[:space:]]*\[/ {
        if ($0 ~ /^[[:space:]]*\[model_providers\.peach(\]|\.)/) {
          skip=1
          next
        }
        skip=0
        table=$0
      }
      skip { next }
      table == "root" && /^[[:space:]]*model_provider[[:space:]]*=/ { next }
      { print }
    ' "$config_file" >"$tmp_file"
  else
    : >"$tmp_file"
  fi

  escaped_base="$(toml_escape "$codex_base_url")"
  escaped_helper="$(toml_escape "$HELPER")"
  cat >>"$tmp_file" <<EOF

# BEGIN Peach Code managed
model_provider = "peach"

[model_providers.peach]
name = "Peach Code API"
base_url = "$escaped_base"
wire_api = "responses"

[model_providers.peach.auth]
command = "$escaped_helper"
refresh_interval_ms = 0
# END Peach Code managed
EOF

  mv "$tmp_file" "$config_file"
}

configure() {
  endpoint="$(current_endpoint)"

  while [ $# -gt 0 ]; do
    case "$1" in
      --endpoint)
        [ $# -ge 2 ] || die "--endpoint requires a value"
        endpoint="$(normalize_endpoint "$2")"
        shift 2
        ;;
      *)
        die "Unknown configure option: $1"
        ;;
    esac
  done

  mkdir -p "$STATE_DIR"
  printf '%s\n' "$endpoint" >"$ENDPOINT_FILE"
  write_helper
  write_claude_settings "$endpoint"
  write_codex_config "$endpoint"

  log "已写入 Peach Code 配置：$endpoint"
  printf 'Claude: %s\n' "$HOME/.claude/settings.json"
  printf 'Codex:  %s\n' "${CODEX_HOME:-$HOME/.codex}/config.toml"
}

auth() {
  mkdir -p "$STATE_DIR"
  printf '\n请打开 Peach Code 获取 API Key：\n%s\n\n' "$KEY_URL"
  printf '请粘贴 API Key：'

  if [ -t 0 ]; then
    old_stty="$(stty -g 2>/dev/null || true)"
    stty -echo 2>/dev/null || true
    read -r api_key || api_key=""
    [ -n "$old_stty" ] && stty "$old_stty" 2>/dev/null || true
    printf '\n'
  else
    read -r api_key || api_key=""
  fi

  [ -n "$api_key" ] || die "API Key 不能为空。"
  umask 077
  printf '%s\n' "$api_key" >"$API_KEY_FILE"
  chmod 600 "$API_KEY_FILE"
  log "API Key 已保存到 $API_KEY_FILE"
}

endpoint() {
  if [ $# -gt 0 ]; then
    case "$1" in
      primary) configure --endpoint "$PRIMARY_ENDPOINT" ;;
      speed) configure --endpoint "$SPEED_ENDPOINT" ;;
      http://* | https://*) configure --endpoint "$1" ;;
      *) die "Usage: peach-code endpoint [primary|speed|https://custom.example.com]" ;;
    esac
    return
  fi

  printf '\n当前线路：%s\n\n' "$(current_endpoint)"
  printf '请选择 Peach Code 线路：\n'
  printf '  1) 主线路       %s\n' "$PRIMARY_ENDPOINT"
  printf '  2) CMIN2 直连   %s\n' "$SPEED_ENDPOINT"
  printf '选择 [1/2]: '
  read -r choice || choice=""

  case "$choice" in
    2) configure --endpoint "$SPEED_ENDPOINT" ;;
    1 | "") configure --endpoint "$PRIMARY_ENDPOINT" ;;
    *) die "无法识别的选择：$choice" ;;
  esac
}

doctor() {
  printf 'Peach Code manager: %s\n' "$PEACH_CODE_VERSION"
  printf 'Endpoint: %s\n' "$(current_endpoint)"
  printf 'Key file: %s ' "$API_KEY_FILE"
  if [ -s "$API_KEY_FILE" ]; then
    printf '(exists, %s bytes)\n' "$(wc -c <"$API_KEY_FILE" | tr -d ' ')"
  else
    printf '(missing)\n'
  fi

  for cmd in claude codex curl; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%s: %s\n' "$cmd" "$(command -v "$cmd")"
    else
      printf '%s: missing\n' "$cmd"
    fi
  done

  claude_settings="$HOME/.claude/settings.json"
  codex_config="${CODEX_HOME:-$HOME/.codex}/config.toml"
  [ -f "$claude_settings" ] && grep -q 'ANTHROPIC_BASE_URL' "$claude_settings" && printf 'Claude config: ok\n' || printf 'Claude config: missing Peach Code base URL\n'
  [ -f "$codex_config" ] && grep -q '\[model_providers.peach\]' "$codex_config" && printf 'Codex config: ok\n' || printf 'Codex config: missing Peach Code provider\n'
}

extract_remote_version() {
  awk -F= '/^PEACH_CODE_VERSION=/{ gsub(/["'\'' ]/, "", $2); print $2; exit }' "$1"
}

update_manager() {
  check_only=0
  force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --check) check_only=1; shift ;;
      --force) force=1; shift ;;
      *) die "Usage: peach-code update [--check] [--force]" ;;
    esac
  done

  url="$(install_url)"
  command -v curl >/dev/null 2>&1 || die "curl is required for updates."
  tmp="$(mktemp "${TMPDIR:-/tmp}/peach-code-install.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  log "正在检查更新：$url"
  curl -fsSL "$url" -o "$tmp"

  remote_version="$(extract_remote_version "$tmp")"
  [ -n "$remote_version" ] || die "无法从远程安装脚本读取版本号。"

  if [ "$remote_version" = "$PEACH_CODE_VERSION" ] && [ "$force" -eq 0 ]; then
    log "已经是最新版本：$PEACH_CODE_VERSION"
    return
  fi

  printf '本地版本：%s\n远程版本：%s\n' "$PEACH_CODE_VERSION" "$remote_version"
  [ "$check_only" -eq 0 ] || return

  log "正在自动获取并执行新版安装器..."
  PEACH_CODE_INSTALL_URL="$url" \
    PEACH_CODE_ENDPOINT="$(current_endpoint)" \
    PEACH_CODE_SKIP_AUTH=1 \
    bash "$tmp"
}

verify() {
  for cmd in claude codex; do
    if command -v "$cmd" >/dev/null 2>&1; then
      "$cmd" --version 2>/dev/null || true
    else
      warn "$cmd 还不在 PATH 中。请重新打开终端，或确认安装输出。"
    fi
  done
}

help_text() {
  cat <<HELP
Peach Code manager ${PEACH_CODE_VERSION}

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
HELP
}

main() {
  cmd="${1:-help}"
  shift || true

  case "$cmd" in
    auth) auth "$@" ;;
    endpoint) endpoint "$@" ;;
    configure) configure "$@" ;;
    doctor) doctor "$@" ;;
    update) update_manager "$@" ;;
    verify) verify "$@" ;;
    version | --version | -v) printf '%s\n' "$PEACH_CODE_VERSION" ;;
    help | --help | -h) help_text ;;
    *) die "Unknown command: $cmd" ;;
  esac
}

main "$@"
MANAGER
  chmod 700 "$MANAGER"

  if ln -sf "$MANAGER" "$LOCAL_BIN/peach-code" 2>/dev/null; then
    :
  else
    cat >"$LOCAL_BIN/peach-code" <<EOF
#!/usr/bin/env sh
exec "$MANAGER" "\$@"
EOF
    chmod 700 "$LOCAL_BIN/peach-code"
  fi
}

setup_shell_path() {
  case ":$PATH:" in
    *":$LOCAL_BIN:"*) return ;;
  esac

  block='
# Peach Code CLI
export PATH="$HOME/.local/bin:$PATH"
'

  wrote_profile=0
  for profile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    should_write=0
    [ -f "$profile" ] && should_write=1
    case "${SHELL:-}" in
      */zsh) [ "$profile" = "$HOME/.zshrc" ] && should_write=1 ;;
      */bash) [ "$profile" = "$HOME/.bashrc" ] && should_write=1 ;;
    esac

    if [ "$should_write" -eq 1 ] && ! grep -q 'Peach Code CLI' "$profile" 2>/dev/null; then
      touch "$profile"
      printf '%s\n' "$block" >>"$profile"
      log "已将 $LOCAL_BIN 加入 $profile"
      wrote_profile=1
    fi
  done

  if [ "$wrote_profile" -eq 0 ]; then
    profile="$HOME/.profile"
    if ! grep -q 'Peach Code CLI' "$profile" 2>/dev/null; then
      touch "$profile"
      printf '%s\n' "$block" >>"$profile"
      log "已将 $LOCAL_BIN 加入 $profile"
    fi
  fi
}

install_clis() {
  need_cmd curl

  if [ "${PEACH_CODE_DRY_RUN:-}" = "1" ]; then
    log "DRY RUN: 跳过 Claude Code 和 Codex CLI 官方安装器。"
    return
  fi

  log "正在安装或更新 Claude Code CLI..."
  curl -fsSL https://claude.ai/install.sh | bash

  log "正在安装或更新 Codex CLI..."
  curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
}

prompt_auth_if_needed() {
  if [ "${PEACH_CODE_SKIP_AUTH:-}" = "1" ]; then
    if [ -s "$API_KEY_FILE" ]; then
      log "保留现有 API Key：$API_KEY_FILE"
    else
      warn "已跳过 API Key 输入；稍后请运行 peach-code auth。"
    fi
    return
  fi

  "$MANAGER" auth
}

verify_install() {
  if [ "${PEACH_CODE_DRY_RUN:-}" = "1" ]; then
    log "DRY RUN: 跳过 CLI 验证。"
    return
  fi

  "$MANAGER" verify
}

main() {
  case "${1:-}" in
    --help | -h)
      usage
      return
      ;;
  esac

  endpoint="$(select_endpoint)"
  endpoint="$(normalize_endpoint "$endpoint")"

  log "Peach Code 安装器 ${PEACH_CODE_VERSION}"
  log "将使用端点：$endpoint"

  mkdir -p "$STATE_DIR" "$BIN_DIR" "$LOCAL_BIN"
  printf '%s\n' "$DEFAULT_INSTALL_URL" >"$INSTALL_URL_FILE"

  install_clis
  write_manager
  setup_shell_path

  log "先写入 Peach Code 中转站配置..."
  "$MANAGER" configure --endpoint "$endpoint"

  prompt_auth_if_needed
  verify_install

  cat <<DONE

Peach Code 已配置完成。

后续可直接在 terminal 运行：
  peach-code auth              # 更新 API Key
  peach-code endpoint          # 切换线路
  peach-code doctor            # 检查安装状态
  peach-code update            # 检测并获取新版本脚本

如果 peach-code 命令暂时不可用，请重新打开终端，或运行：
  export PATH="$LOCAL_BIN:\$PATH"
DONE
}

main "$@"
