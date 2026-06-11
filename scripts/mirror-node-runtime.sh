#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="${NODE_VERSION:-v24.16.0}"
REPO="${REPO:-yellowpeachxgp/peach-code-launcher}"
TAG="${TAG:-node-runtime-v24.16.0}"
DIST_BASE="${DIST_BASE:-https://nodejs.org/dist/${NODE_VERSION}}"
WORK_DIR="${WORK_DIR:-$(pwd)/.tmp/node-runtime-${NODE_VERSION}}"

FILES=(
  "node-${NODE_VERSION}-darwin-arm64.tar.xz"
  "node-${NODE_VERSION}-darwin-x64.tar.xz"
  "node-${NODE_VERSION}-linux-arm64.tar.xz"
  "node-${NODE_VERSION}-linux-x64.tar.xz"
  "node-${NODE_VERSION}-win-arm64.zip"
  "node-${NODE_VERSION}-win-x64.zip"
)

log() {
  printf '==> %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
    return
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
    return
  fi

  die "Missing shasum or sha256sum."
}

curl_download() {
  if curl --help all 2>/dev/null | grep -q -- '--retry-all-errors'; then
    curl --retry 5 --retry-all-errors --retry-delay 2 -fsSLO "$1"
  else
    curl --retry 5 --retry-delay 2 -fsSLO "$1"
  fi
}

platform_for_file() {
  case "$1" in
    *darwin-arm64*) printf 'darwin arm64\n' ;;
    *darwin-x64*) printf 'darwin x64\n' ;;
    *linux-arm64*) printf 'linux arm64\n' ;;
    *linux-x64*) printf 'linux x64\n' ;;
    *win-arm64*) printf 'win arm64\n' ;;
    *win-x64*) printf 'win x64\n' ;;
    *) die "Unknown platform for $1" ;;
  esac
}

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

log "Downloading Node.js checksums: ${DIST_BASE}/SHASUMS256.txt"
curl_download "${DIST_BASE}/SHASUMS256.txt"

manifest="$WORK_DIR/node-manifest.json"
cat >"$manifest" <<EOF
{
  "version": "${NODE_VERSION}",
  "releaseTag": "${TAG}",
  "source": "${DIST_BASE}",
  "assets": [
EOF

last_index=$((${#FILES[@]} - 1))
for index in "${!FILES[@]}"; do
  file="${FILES[$index]}"
  expected="$(awk -v f="$file" '$2 == f { print $1 }' SHASUMS256.txt)"
  [ -n "$expected" ] || die "No checksum found for $file"

  log "Downloading $file"
  curl_download "${DIST_BASE}/${file}"

  actual="$(sha256_file "$file")"
  [ "$actual" = "$expected" ] || die "Checksum mismatch for $file"

  read -r platform arch < <(platform_for_file "$file")
  comma=","
  if [ "$index" -eq "$last_index" ]; then
    comma=""
  fi
  cat >>"$manifest" <<EOF
    {
      "platform": "${platform}",
      "arch": "${arch}",
      "filename": "${file}",
      "sha256": "${actual}"
    }${comma}
EOF
done

cat >>"$manifest" <<'EOF'

  ]
}
EOF

if ! command -v gh >/dev/null 2>&1; then
  log "gh is not installed. Assets are ready in: $WORK_DIR"
  exit 0
fi

if ! gh api user >/dev/null 2>&1; then
  log "gh is not authenticated. Assets are ready in: $WORK_DIR"
  exit 0
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  log "Release $TAG exists."
else
  log "Creating release $TAG"
  gh release create "$TAG" --repo "$REPO" --title "Node.js runtime ${NODE_VERSION}" --notes "Mirrored portable Node.js runtime assets for Peach Code Launcher."
fi

log "Uploading assets to $REPO@$TAG"
gh release upload "$TAG" --repo "$REPO" --clobber node-manifest.json "${FILES[@]}"
log "Done."
