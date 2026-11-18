# Validação da beta

## Automatizada

`bash scripts/build-macos-manager.sh` compila o app e executa os 19 testes do
gerenciador, usando perfis sintéticos e pastas temporárias. A assinatura local
e o `Info.plist` também são verificados.

`bash scripts/package-macos-manager.sh` executa também os 9 testes do
instalador em volumes temporários: instalação nova, atualização de build e
versão, reinstalação, bloqueio de downgrade, destino de outro aplicativo,
link simbólico e metadados inválidos. Os testes verificam que os dados
sintéticos das contas e a preferência do mascote permanecem intactos.

Para repetir somente os testes:

```sh
dist/MultiCodex.app/Contents/MacOS/MultiCodex --self-test
```

O empacotamento gera um ZIP, um PKG e hashes SHA-256. A validação dos testes
não equivale a um teste de login real nem a uma conferência visual da janela.

## Conferência manual antes de uma versão estável

Use contas e arquivos próprios para teste, sem publicar suas credenciais.

1. Instalar o pacote em Aplicativos e abrir o app pelo Finder.
2. Conferir a lista com uma instalação já configurada e com uma instalação nova.
3. Criar um perfil, entrar com outra conta no Codex e confirmar que a conta
   original continua aberta com seu próprio login.
4. Abrir o mesmo perfil novamente e conferir se a janela existente recebe foco.
5. Editar nome e cor e conferir o aplicativo correspondente no Finder.
6. Arquivar e restaurar um perfil e conferir que o ID e o login foram mantidos.
7. Conectar um plugin, selecionar o perfil de destino e confirmar a conexão
   apenas nessa janela.
8. Fechar e abrir o gerenciador, reiniciar o Mac e conferir a persistência.
9. Conferir a interface no tamanho mínimo da janela, com nomes longos, com
   várias contas e com VoiceOver e navegação por teclado.
10. Conferir o gato robô dormindo no contador e escolher macho e fêmea em
    Personalizar; reabrir o app e confirmar a persistência e o ícone no Dock.
11. Atualizar uma instalação anterior pelo `.pkg`, confirmar a detecção da
    versão instalada e verificar as mesmas contas e preferências após abrir.

A validação gráfica e o fluxo real de login permanecem pendentes na primeira
beta quando não houver acesso a uma sessão gráfica para executá-los.
