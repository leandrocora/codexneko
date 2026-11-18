# CodexNeko para macOS

Aplicativo nativo em português para adicionar e abrir contas do Codex sem
usar comandos no Terminal. Requer macOS 13 ou posterior em Mac Apple Silicon
e o aplicativo oficial do Codex instalado.

## Uso

1. Abra `CodexNeko.app`. Você pode arrastá-lo para a pasta Aplicativos.
2. Os perfis existentes aparecem automaticamente.
3. Clique em **Adicionar conta**, escolha um nome e uma cor e clique em
   **Criar e abrir**.
4. Faça login na outra conta dentro da nova janela do Codex.
5. Use **Abrir conta** para voltar a qualquer janela.

Você não precisa fornecer senhas ao gerenciador. Os perfis usam o aplicativo
oficial do Codex, cada um com seu próprio login. Fechar o gerenciador não fecha
as janelas do Codex.

No menu de cada conta é possível editar nome e cor ou arquivá-la. O
arquivamento mantém o login e os dados e pode ser desfeito em **Arquivadas**.
A instalação original permanece disponível como conta principal. Configurações
de compartilhamento feitas anteriormente no Multi Codex são respeitadas.

O app usa modo escuro. Em **Personalizar** (`⌘,`), escolha o gato robô macho
(padrão, luz azul) ou fêmea (luz rosa e laço metálico). O mascote dorme deitado
ao lado do contador de janelas abertas; o ícone no Dock acompanha a escolha.
A preferência continua salva ao fechar o app e ao atualizar.

Para atualizar, abra o novo instalador `.pkg`. Ele detecta a instalação em
Aplicativos, atualiza o mesmo app e preserva contas e preferências. Instalações
mais novas não são substituídas por versões antigas.

Instalações anteriores com o nome MultiCodex também são reconhecidas pelo
`.pkg`. Depois de validar o CodexNeko instalado, o instalador guarda o app
anterior em `/Library/Application Support/CodexNeko/Previous Versions/`.
Os dados das contas e a preferência do mascote continuam nos mesmos locais.

**Como funciona → Manutenção** oferece verificação e reparo da instalação.
Os nomes informados no gerenciador são apelidos locais, não endereços de login.

## Dados e distribuição

O gerenciador reconhece a instalação padrão em
`~/Library/Application Support/Multi Codex`. A primeira configuração é feita
automaticamente ao criar a primeira conta. Perfis e credenciais ficam fora
do pacote do aplicativo. O ZIP distribuído não inclui dados de contas.

O app é assinado localmente, sem notarização Apple. Uma cópia baixada da
internet pode precisar ser liberada em Ajustes do Sistema → Privacidade e
Segurança → Abrir Mesmo Assim. Não é necessário desativar o Gatekeeper.

## Compilar e testar

Na raiz do projeto, execute:

```sh
bash scripts/build-macos-manager.sh
```

Requer as ferramentas Swift da Apple. A compilação usa somente o SDK local,
sem dependências externas ou downloads. O executável de perfis validado
deve estar em `release/multi-codex-app`.

O script executa os testes do gerenciador com dados sintéticos em pasta
temporária. Também é possível rodá-los com:

```sh
dist/CodexNeko.app/Contents/MacOS/CodexNeko --self-test
```

O gerenciamento é uma interface para `am-will/multi-codex-app v0.2.1`, sob MIT.
Os testes de integração verificam o contrato com o executável original, sem
alterar contas reais, LaunchAgents ou preferências do macOS.
