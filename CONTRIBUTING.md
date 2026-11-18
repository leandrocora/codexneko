# Como contribuir

Issues, correções e melhorias são bem-vindas. A interface atual usa SwiftUI e
AppKit e é compilada para macOS Apple Silicon.

## Preparar o ambiente

1. Instale as ferramentas Swift da Apple em um Mac Apple Silicon.
2. Clone o repositório.
3. Execute `bash scripts/download-manager-backend.sh`.
4. Execute `bash scripts/build-macos-manager.sh`.

O último comando compila e executa os testes do gerenciador.
Não é preciso instalar Go para trabalhar na interface gráfica.

## Antes de enviar um pull request

- Explique o problema e o comportamento resultante.
- Execute a compilação e os testes relevantes para sua mudança.
- Para mudanças de interface, inclua imagens usando apenas contas fictícias.
- Para mudanças no backend, preserve perfis, IDs, autenticação e campos
  desconhecidos das configurações.
- Nunca envie sua pasta de perfis, arquivos `auth.json`, bancos ou tokens.

Os testes de `native/manager/SelfTests.swift` usam instalações sintéticas em
pastas temporárias. Amplie a cobertura quando a mudança criar um comportamento
novo ou corrigir uma falha de integração.

## Empacotar

`bash scripts/package-macos-manager.sh` gera ZIP, instalador e checksums em
`dist/`. Os pacotes não são versionados no Git; são anexados às releases.

O script `scripts/export-public-source.py` usa uma lista explícita de diretórios
e faz uma verificação básica de dados locais antes da exportação. Isso
complementa a revisão do conteúdo que será publicado.

## Licença

As contribuições de código são disponibilizadas sob a licença MIT do projeto.
Preserve os créditos dos componentes de terceiros.
