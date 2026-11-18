#!/bin/bash
set -euo pipefail
MANAGER_PACKAGE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANAGER_BUNDLE="$MANAGER_PACKAGE_ROOT/dist/CodexNeko.app"
MANAGER_PACKAGE_NAME="CodexNeko-macOS-AppleSilicon.zip"
MANAGER_INSTALLER_NAME="CodexNeko-macOS-Installer.pkg"
if [[ "${1:-}" == --skip-build && $# == 1 ]]; then
  :
elif [[ $# == 0 ]]; then
  bash "$MANAGER_PACKAGE_ROOT/scripts/download-manager-backend.sh"
  bash "$MANAGER_PACKAGE_ROOT/scripts/build-macos-manager.sh"
else
  echo 'Uso: bash scripts/package-macos-manager.sh [--skip-build]' >&2
  exit 1
fi
test -x "$MANAGER_BUNDLE/Contents/MacOS/CodexNeko"
/usr/bin/codesign --verify --deep --strict "$MANAGER_BUNDLE"
/usr/bin/plutil -lint "$MANAGER_BUNDLE/Contents/Info.plist"
python3 "$MANAGER_PACKAGE_ROOT/scripts/test-installer.py"
echo 'Criando o ZIP do aplicativo…'
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$MANAGER_BUNDLE" "$MANAGER_PACKAGE_ROOT/dist/$MANAGER_PACKAGE_NAME"
echo 'Criando o instalador para Aplicativos…'
mkdir -p "$MANAGER_PACKAGE_ROOT/.build"
MANAGER_PAYLOAD="$(mktemp -d "$MANAGER_PACKAGE_ROOT/.build/pkg-payload-XXXXXX")"
trap 'rm -rf "$MANAGER_PAYLOAD"' EXIT
MANAGER_INSTALLER_BUILD="$MANAGER_PAYLOAD/InstallerBuild"
python3 "$MANAGER_PACKAGE_ROOT/scripts/prepare-installer.py" "$MANAGER_BUNDLE" "$MANAGER_INSTALLER_BUILD"
MANAGER_PACKAGE_VERSION="$(cat "$MANAGER_INSTALLER_BUILD/PackageVersion.txt")"
mkdir -p "$MANAGER_PAYLOAD/Applications"
/usr/bin/ditto "$MANAGER_BUNDLE" "$MANAGER_PAYLOAD/Applications/CodexNeko.app"
MANAGER_COMPONENTS="$MANAGER_PACKAGE_ROOT/.build/manager-package-components.plist"
mkdir -p "$MANAGER_PAYLOAD/Payload/Applications"
mv "$MANAGER_PAYLOAD/Applications/CodexNeko.app" "$MANAGER_PAYLOAD/Payload/Applications/CodexNeko.app"
/usr/bin/pkgbuild --analyze --root "$MANAGER_PAYLOAD/Payload" "$MANAGER_COMPONENTS"
python3 - "$MANAGER_COMPONENTS" <<'PY'
import plistlib
import sys
from pathlib import Path
path = Path(sys.argv[1])
components = plistlib.loads(path.read_bytes())
for component in components:
    component["BundleIsRelocatable"] = False
    component["BundleIsVersionChecked"] = True
    component["BundleHasStrictIdentifier"] = True
    component["BundleOverwriteAction"] = "upgrade"
path.write_bytes(plistlib.dumps(components))
PY
/usr/bin/pkgbuild --root "$MANAGER_PAYLOAD/Payload" --component-plist "$MANAGER_COMPONENTS" --install-location / \
  --scripts "$MANAGER_INSTALLER_BUILD/Scripts" \
  --identifier com.coradini.multicodex.installer --version "$MANAGER_PACKAGE_VERSION" \
  "$MANAGER_INSTALLER_BUILD/CodexNekoComponent.pkg"
python3 "$MANAGER_PACKAGE_ROOT/scripts/prepare-installer.py" "$MANAGER_BUNDLE" "$MANAGER_INSTALLER_BUILD" --finalize
/usr/bin/productbuild --distribution "$MANAGER_INSTALLER_BUILD/Distribution.xml" \
  --package-path "$MANAGER_INSTALLER_BUILD" --resources "$MANAGER_PACKAGE_ROOT/scripts/installer" \
  "$MANAGER_PACKAGE_ROOT/dist/$MANAGER_INSTALLER_NAME"
cd "$MANAGER_PACKAGE_ROOT/dist"
shasum -a 256 "$MANAGER_PACKAGE_NAME" "$MANAGER_INSTALLER_NAME" > SHA256SUMS.txt
echo "Pacotes prontos: dist/$MANAGER_PACKAGE_NAME e dist/$MANAGER_INSTALLER_NAME"
