#!/bin/bash
set -euo pipefail

MANAGER_PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANAGER_BUILD_ROOT="$MANAGER_PROJECT_ROOT/.build/macos-manager"
MANAGER_APP="$MANAGER_PROJECT_ROOT/dist/CodexNeko.app"
MANAGER_SWIFTC="$(xcrun --find swiftc)"
MANAGER_SDK="$(xcrun --sdk macosx --show-sdk-path)"
MANAGER_BINARY_HASH="df38ea72ac1422756cff08eb57fa933eb69fb3ecb5d8366be608307b372ddc54"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo 'Este pacote usa a versão macOS Apple Silicon do Multi Codex.' >&2
  exit 1
fi
if [[ ! -x "$MANAGER_PROJECT_ROOT/release/multi-codex-app" ]]; then
  echo 'Falta release/multi-codex-app v0.2.1 para macOS arm64.' >&2
  exit 1
fi
if [[ "$(shasum -a 256 "$MANAGER_PROJECT_ROOT/release/multi-codex-app" | cut -d ' ' -f 1)" != "$MANAGER_BINARY_HASH" ]]; then
  echo 'A verificação do executável Multi Codex falhou.' >&2
  exit 1
fi

mkdir -p "$MANAGER_BUILD_ROOT/ModuleCache" "$MANAGER_APP/Contents/MacOS" "$MANAGER_APP/Contents/Resources/ProfileIcons" "$MANAGER_APP/Contents/Resources/BrandAssets"
for MANAGER_ASSET in CatMale CatFemale AppIconMale AppIconFemale; do
  test -f "$MANAGER_PROJECT_ROOT/native/manager/Assets/Brand/$MANAGER_ASSET.png"
  cp "$MANAGER_PROJECT_ROOT/native/manager/Assets/Brand/$MANAGER_ASSET.png" "$MANAGER_APP/Contents/Resources/BrandAssets/$MANAGER_ASSET.png"
done
cp "$MANAGER_PROJECT_ROOT/release/multi-codex-app" "$MANAGER_APP/Contents/Resources/multi-codex-app"
chmod 755 "$MANAGER_APP/Contents/Resources/multi-codex-app"
cp "$MANAGER_PROJECT_ROOT/LICENSE" "$MANAGER_APP/Contents/Resources/CodexNeko-Backend-LICENSE.txt"
cp "$MANAGER_PROJECT_ROOT/native/manager/ThirdPartyNotices.txt" "$MANAGER_APP/Contents/Resources/ThirdPartyNotices.txt"
cp "$MANAGER_PROJECT_ROOT/cmd/multi-codex-app/assets/icons/"*.png "$MANAGER_APP/Contents/Resources/ProfileIcons/"
cp "$MANAGER_PROJECT_ROOT/native/manager/Info.plist" "$MANAGER_APP/Contents/Info.plist"

echo 'Compilando o aplicativo macOS…'
"$MANAGER_SWIFTC" -swift-version 5 -O -target arm64-apple-macos13.0 -sdk "$MANAGER_SDK" \
  -module-cache-path "$MANAGER_BUILD_ROOT/ModuleCache" \
  "$MANAGER_PROJECT_ROOT/native/manager/Models.swift" \
  "$MANAGER_PROJECT_ROOT/native/manager/Theme.swift" \
  "$MANAGER_PROJECT_ROOT/native/manager/Mascots.swift" \
  "$MANAGER_PROJECT_ROOT/native/manager/Backend.swift" \
  "$MANAGER_PROJECT_ROOT/native/manager/AccountStore.swift" \
  "$MANAGER_PROJECT_ROOT/native/manager/AccountListView.swift" \
  "$MANAGER_PROJECT_ROOT/native/manager/Views.swift" \
  "$MANAGER_PROJECT_ROOT/native/manager/SelfTests.swift" \
  "$MANAGER_PROJECT_ROOT/native/manager/main.swift" \
  -o "$MANAGER_APP/Contents/MacOS/CodexNeko"

echo 'Gerando o ícone…'
"$MANAGER_SWIFTC" -swift-version 5 -target arm64-apple-macos13.0 -sdk "$MANAGER_SDK" \
  -module-cache-path "$MANAGER_BUILD_ROOT/ModuleCache" \
  "$MANAGER_PROJECT_ROOT/native/manager/GenerateIcon.swift" -o "$MANAGER_BUILD_ROOT/generate-icon"
"$MANAGER_BUILD_ROOT/generate-icon" "$MANAGER_BUILD_ROOT/CodexNeko.iconset" "$MANAGER_APP/Contents/Resources/CodexNeko.icns" "$MANAGER_PROJECT_ROOT/native/manager/Assets/Brand/AppIconMale.png"

echo 'Validando o aplicativo…'
"$MANAGER_APP/Contents/MacOS/CodexNeko" --self-test
/usr/bin/plutil -lint "$MANAGER_APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$MANAGER_APP/Contents/Resources/multi-codex-app"
/usr/bin/codesign --force --sign - "$MANAGER_APP"
/usr/bin/codesign --verify --deep --strict "$MANAGER_APP"

echo "App pronto: $MANAGER_APP"
