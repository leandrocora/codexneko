#!/bin/bash
# Preserve the original identifiers so installed receipts and preferences survive.
MANAGER_BUNDLE_ID="com.coradini.multicodex.manager"

manager_fail() {
  printf 'CodexNeko: %s\n' "$1" >&2
  exit 1
}
manager_read() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}
manager_numeric_version() {
  [[ "$1" =~ ^[0-9]+(\.[0-9]+)*$ ]]
}
manager_compare() {
  /usr/bin/awk -v left="$1" -v right="$2" 'BEGIN {
    nl=split(left,l,"."); nr=split(right,r,"."); n=nl>nr?nl:nr;
    for(i=1;i<=n;i++){a=l[i]+0;b=r[i]+0;if(a>b){print 1;exit}if(a<b){print -1;exit}}
    print 0
  }'
}
manager_initialize() {
  MANAGER_TARGET_VOLUME="${1:-/}"
  [[ "$MANAGER_TARGET_VOLUME" == /* && -d "$MANAGER_TARGET_VOLUME" ]] || manager_fail 'Volume de instalação inválido.'
  MANAGER_VOLUME_ROOT="${MANAGER_TARGET_VOLUME%/}"
  MANAGER_CURRENT_APP="$MANAGER_VOLUME_ROOT/Applications/CodexNeko.app"
  MANAGER_LEGACY_APP="$MANAGER_VOLUME_ROOT/Applications/MultiCodex.app"
  MANAGER_NEW_VERSION="$(manager_read "$MANAGER_SCRIPT_ROOT/Version.plist" CFBundleShortVersionString)" || manager_fail 'Pacote incompleto: falta a versão de destino.'
  MANAGER_NEW_BUILD="$(manager_read "$MANAGER_SCRIPT_ROOT/Version.plist" CFBundleVersion)" || manager_fail 'Pacote incompleto: falta o número do build.'
  manager_numeric_version "$MANAGER_NEW_VERSION" && manager_numeric_version "$MANAGER_NEW_BUILD" || manager_fail 'Metadados de versão inválidos no pacote.'
}
manager_check_app() {
  local app="$1" plist="$1/Contents/Info.plist" identifier order build_order
  [[ ! -L "$app" && -d "$app" ]] || manager_fail 'O destino não é um aplicativo válido. A instalação existente foi preservada.'
  identifier="$(manager_read "$plist" CFBundleIdentifier)" || manager_fail 'Não foi possível identificar o aplicativo existente.'
  [[ "$identifier" == "$MANAGER_BUNDLE_ID" ]] || manager_fail 'Outro aplicativo ocupa um destino da instalação. Ele não será substituído.'
  MANAGER_OLD_VERSION="$(manager_read "$plist" CFBundleShortVersionString)" || manager_fail 'A versão instalada não pôde ser lida.'
  MANAGER_OLD_BUILD="$(manager_read "$plist" CFBundleVersion)" || manager_fail 'O build instalado não pôde ser lido.'
  manager_numeric_version "$MANAGER_OLD_VERSION" && manager_numeric_version "$MANAGER_OLD_BUILD" || manager_fail 'A versão instalada tem metadados inválidos. Nenhum dado foi alterado.'
  order="$(manager_compare "$MANAGER_OLD_VERSION" "$MANAGER_NEW_VERSION")"
  build_order="$(manager_compare "$MANAGER_OLD_BUILD" "$MANAGER_NEW_BUILD")"
  if [[ "$order" == 1 || ( "$order" == 0 && "$build_order" == 1 ) ]]; then
    manager_fail "Já existe uma versão mais nova: $MANAGER_OLD_VERSION (build $MANAGER_OLD_BUILD). A instalação foi cancelada para preservar essa versão."
  fi
}
