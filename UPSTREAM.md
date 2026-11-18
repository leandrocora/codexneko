# Origem dos componentes

## Interface macOS

`native/manager/`, scripts do gerenciador, documentação do produto e workflows
de distribuição da interface foram adicionados por Leandro Nery Coradini.
Licença: MIT, conforme o arquivo LICENSE.

## Gerenciamento dos perfis

- Projeto: https://github.com/am-will/multi-codex-app
- Autor: William Ryan (am-will).
- Licença: MIT; o aviso de copyright original foi preservado.
- O código original foi obtido do snapshot de `main` associado ao commit
  `0b82fa5c2cd6618435c390172e5fb99c9b014b8f`.
- O aplicativo gráfico usa o executável publicado **v0.2.1 para darwin/arm64**.
  Ele não recompila o snapshot Go para gerar o backend distribuído.

Os diretórios `cmd/multi-codex-app/`, `native/macos/`, o módulo Go e os
instaladores originais foram mantidos para referência e continuidade da licença.
As versões originais de README, release notes e workflows estão em
`docs/upstream/`.

### Integridade do backend fixo

```text
multi-codex-app_darwin_arm64.tar.gz
b2e9f3d23ee916f6f08eb7928d112d0de39cc6bef665e2e779f52d5aa5354736

Executável extraído, antes da assinatura local
df38ea72ac1422756cff08eb57fa933eb69fb3ecb5d8366be608307b372ddc54
```

A assinatura local do executável incorporado ao `.app` muda seus bytes.
Os hashes acima validam o download e o executável original antes dessa etapa.

## Créditos adicionais e marcas

O projeto original credita Edi Hasaj pela metodologia de contas separadas:
https://edihasaj.com/posts/two-codex-accounts-two-dock-icons-macos

Os ícones originais podem conter a marca OpenAI, que não é licenciada pela MIT.
Consulte `cmd/multi-codex-app/assets/icons/README.md`. OpenAI, ChatGPT e Codex
são marcas de seus respectivos titulares. Este projeto é independente.
