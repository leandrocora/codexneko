# Arquitetura

O app é um shell gráfico nativo para o gerenciador original. Não implementa
um cliente de IA, proxy de autenticação ou uma versão modificada do Codex.

| Componente | Responsabilidade |
| --- | --- |
| `main.swift` | Ciclo de vida AppKit, janela, menus e atualização da lista |
| `AccountListView.swift` | Lista de contas, avatares, status e ações |
| `Views.swift` | Edição, ajuda e diagnósticos |
| `AccountStore.swift` | Estado da interface e execução serial das operações |
| `Models.swift` | Leitura dos perfis e validação dos nomes |
| `Backend.swift` | Chamadas ao CLI, timeout, bloqueio e tratamento de operações parciais |
| `SelfTests.swift` | Instalações sintéticas, falhas e contrato com o CLI real |

## Dados e comandos

A interface lê `config.json` da instalação padrão. Alterações são feitas pelo
CLI, evitando regravar a configuração pela interface e descartar campos que
pertençam a outras versões.

Criar uma conta usa `add --count 1 --no-dock`, seguido por `rename`, `icon` e
`launch`. Em uma instalação nova, `setup --count 2` preserva a instalação
original como perfil 1 e cria o perfil adicional. A interface não copia tokens.

Os comandos usam `Process` e argumentos separados. Variáveis herdadas de
identidade e dados do Codex são removidas do ambiente da chamada; a raiz do
gerenciador é fornecida explicitamente. Um lock por instalação evita duas
mutações simultâneas iniciadas por janelas do gerenciador.

Se parte da criação já foi salva e uma etapa posterior falha, o perfil é
mostrado na lista com um aviso. A operação não é repetida automaticamente,
evitando contas duplicadas.

O gerenciador usa o CLI instalado quando disponível e o executável incorporado
como alternativa. O helper original continua responsável por receber e
encaminhar conexões para a janela escolhida.

## Distribuição

O build incorpora apenas executáveis, ícones e avisos de licença. Os perfis
ficam fora do `.app`. O ZIP preserva o pacote e os modos de execução. O PKG
tem como destino `/Applications/MultiCodex.app` e não inclui scripts de remoção
ou migração de contas.

Os workflows usam runners macOS Apple Silicon para build e testes; apenas o
job de publicação da release recebe permissão de escrita no conteúdo do GitHub.
