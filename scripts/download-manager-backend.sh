#!/bin/bash
set -euo pipefail
MANAGER_SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANAGER_RELEASE_DIR="$MANAGER_SOURCE_ROOT/release"
MANAGER_BACKEND_VERSION="v0.2.1"
MANAGER_ARCHIVE="multi-codex-app_darwin_arm64.tar.gz"
MANAGER_ARCHIVE_HASH="b2e9f3d23ee916f6f08eb7928d112d0de39cc6bef665e2e779f52d5aa5354736"
MANAGER_EXECUTABLE_HASH="df38ea72ac1422756cff08eb57fa933eb69fb3ecb5d8366be608307b372ddc54"
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  echo 'A distribuição atual requer macOS em Apple Silicon.' >&2
  exit 1
fi
mkdir -p "$MANAGER_RELEASE_DIR"
if [[ -f "$MANAGER_RELEASE_DIR/multi-codex-app" ]]; then
  MANAGER_FOUND_HASH="$(shasum -a 256 "$MANAGER_RELEASE_DIR/multi-codex-app" | cut -d ' ' -f 1)"
  if [[ "$MANAGER_FOUND_HASH" == "$MANAGER_EXECUTABLE_HASH" ]]; then
    chmod 755 "$MANAGER_RELEASE_DIR/multi-codex-app"
    echo "Backend $MANAGER_BACKEND_VERSION já verificado."
    exit 0
  fi
  echo 'Existe um backend diferente em release/. Ele não foi substituído.' >&2
  exit 1
fi
MANAGER_DOWNLOAD_TEMP="$(mktemp -d)"
trap 'rm -rf "$MANAGER_DOWNLOAD_TEMP"' EXIT
MANAGER_DOWNLOAD_URL="https://github.com/am-will/multi-codex-app/releases/download/$MANAGER_BACKEND_VERSION/$MANAGER_ARCHIVE"
curl --proto '=https' --tlsv1.2 -fL --retry 2 --connect-timeout 15 --max-time 120 \
  "$MANAGER_DOWNLOAD_URL" -o "$MANAGER_DOWNLOAD_TEMP/$MANAGER_ARCHIVE"
MANAGER_FOUND_HASH="$(shasum -a 256 "$MANAGER_DOWNLOAD_TEMP/$MANAGER_ARCHIVE" | cut -d ' ' -f 1)"
if [[ "$MANAGER_FOUND_HASH" != "$MANAGER_ARCHIVE_HASH" ]]; then
  echo 'SHA-256 do download não confere. O executável não foi instalado.' >&2
  exit 1
fi
tar -xzf "$MANAGER_DOWNLOAD_TEMP/$MANAGER_ARCHIVE" -C "$MANAGER_DOWNLOAD_TEMP" multi-codex-app
MANAGER_FOUND_HASH="$(shasum -a 256 "$MANAGER_DOWNLOAD_TEMP/multi-codex-app" | cut -d ' ' -f 1)"
if [[ "$MANAGER_FOUND_HASH" != "$MANAGER_EXECUTABLE_HASH" ]]; then
  echo 'SHA-256 do executável não confere.' >&2
  exit 1
fi
cp "$MANAGER_DOWNLOAD_TEMP/multi-codex-app" "$MANAGER_RELEASE_DIR/multi-codex-app"
cp "$MANAGER_DOWNLOAD_TEMP/$MANAGER_ARCHIVE" "$MANAGER_RELEASE_DIR/$MANAGER_ARCHIVE"
chmod 755 "$MANAGER_RELEASE_DIR/multi-codex-app"
echo "Backend $MANAGER_BACKEND_VERSION baixado e verificado."
