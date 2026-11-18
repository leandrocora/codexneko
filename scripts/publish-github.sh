#!/bin/bash
set -euo pipefail
MANAGER_PUBLISH_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANAGER_REPO="${1:-leandrocora/multicodex-macos}"
MANAGER_TAG="v1.0.0-beta.3"
if [[ $# -gt 1 || ! "$MANAGER_REPO" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$ ]]; then
  echo 'Uso: bash scripts/publish-github.sh [usuario/repositorio]' >&2
  exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  echo 'GitHub CLI não está instalado. Instale em https://cli.github.com e autentique com gh auth login.' >&2
  exit 1
fi
gh auth status
MANAGER_ACCOUNT="$(gh api user --jq .login)"
if [[ "${MANAGER_REPO%%/*}" != "$MANAGER_ACCOUNT" ]]; then
  echo "O GitHub CLI está conectado a $MANAGER_ACCOUNT; o destino pedido é ${MANAGER_REPO%%/*}. Nenhum repositório foi criado." >&2
  exit 1
fi
mkdir -p "$MANAGER_PUBLISH_ROOT/.build"
MANAGER_PUBLISH_STAGE="$(mktemp -d "$MANAGER_PUBLISH_ROOT/.build/github-publish-XXXXXX")"
python3 "$MANAGER_PUBLISH_ROOT/scripts/export-public-source.py" --directory "$MANAGER_PUBLISH_STAGE"
git -C "$MANAGER_PUBLISH_STAGE" init -b main
git -C "$MANAGER_PUBLISH_STAGE" add .
git -C "$MANAGER_PUBLISH_STAGE" -c user.name="$MANAGER_ACCOUNT" \
  -c user.email="$MANAGER_ACCOUNT@users.noreply.github.com" \
  commit -m 'Release MultiCodex macOS account manager with documentation and build workflows'
if gh repo view "$MANAGER_REPO" --json nameWithOwner >/dev/null 2>&1; then
  echo "O repositório $MANAGER_REPO já existe. Nenhum conteúdo remoto foi substituído." >&2
  echo "Código preparado em: $MANAGER_PUBLISH_STAGE" >&2
  exit 1
fi
gh repo create "$MANAGER_REPO" --public --source "$MANAGER_PUBLISH_STAGE" --remote origin --push \
  --description 'Gerenciador gratuito e open source de contas Codex para macOS. Adicione e abra perfis sem usar o Terminal.'
gh repo edit "$MANAGER_REPO" --add-topic macos --add-topic swift --add-topic swiftui --add-topic codex --add-topic account-manager
git -C "$MANAGER_PUBLISH_STAGE" tag -a "$MANAGER_TAG" -m 'MultiCodex 1.0.0 beta 3'
git -C "$MANAGER_PUBLISH_STAGE" push origin "$MANAGER_TAG"
echo "Repositório público: https://github.com/$MANAGER_REPO"
echo "O GitHub Actions vai compilar e disponibilizar os downloads em: https://github.com/$MANAGER_REPO/releases"
