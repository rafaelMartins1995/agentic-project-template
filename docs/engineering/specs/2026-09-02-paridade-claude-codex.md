# Paridade de host entre Claude Code e Codex — SPEC

- ID: SPEC-001
- Status: aprovada
- Responsável: rafaelMartins1995
- Data: 2026-09-02

## Problema e objetivo

O template funciona integralmente apenas no Claude Code. Quem usa Codex recebe as
regras de processo, porque o Codex lê `AGENTS.md` nativamente, mas perde três
capacidades: o bootstrap não roda, o Superpowers não é instalado e os subagentes
não existem.

Objetivo: fazer com que um usuário de Codex e um usuário de Claude Code obtenham o
mesmo conjunto de funcionalidades a partir do mesmo repositório, sem duplicar as
regras do projeto e sem amarrar o template a um fornecedor.

## Usuários e cenários

1. Pessoa clona o template e usa Claude Code. O comportamento atual continua idêntico.
2. Pessoa clona o template e usa Codex. Roda o mesmo comando de bootstrap e recebe
   Superpowers instalado, subagentes disponíveis e a entrevista em pt-BR.
3. Pessoa tem os dois instalados. O bootstrap pergunta qual usar.
4. Pessoa não tem nenhum dos dois. O bootstrap não altera nada e mostra as instruções
   oficiais de instalação dos dois hosts.
5. Automação precisa escolher o host sem interação.

## Contexto atual

- `AGENTS.md` concentra as regras duráveis e é lido nativamente pelos dois hosts.
- `CLAUDE.md` carrega três regras que não existem em nenhum outro lugar: responder em
  português do Brasil, seguir `prompts/INICIAR_PROJETO.md` na primeira execução e usar
  os subagentes conforme `.agents/ROUTING.md`. O Codex não lê esse arquivo.
- `iniciar.sh`, `iniciar.ps1` e `iniciar.cmd` procuram apenas o binário `claude` e saem
  com código 2 sem ele.
- Os 8 subagentes existem só em `.claude/agents/*.md`. O corpo de cada um é um ponteiro
  curto para o perfil correspondente em `.agents/profiles/`.
- `scripts/validate_template.py` reprova o repositório se a string `codex` aparecer em
  qualquer arquivo `.md`, `.sh`, `.ps1`, `.cmd` ou `.py`.
- `tests/test_bootstrap.sh` cobre apenas `iniciar.sh`. O `iniciar.ps1` nunca teve teste.
- `.agents/profiles/dependencies.md` cita um host específico ao delimitar o escopo do
  auditor de dependências.
- `PROJECT_PROFILE.md` e `AGENT_CATALOG.md` não têm campo para registrar o host usado.
- O Codex possui subagentes nativos declarados em `.codex/agents/*.toml`, sistema de
  plugins com subcomandos não interativos e o Superpowers publicado no marketplace
  oficial `openai/plugins`.
- O binário `codex` não está instalado na máquina de desenvolvimento atual.

## Escopo

- Manifesto canônico de papéis e gerador dos dois formatos de subagente.
- Bootstrap com detecção de host, seleção interativa no empate e seleção explícita por
  flag ou variável de ambiente.
- Instalação do Superpowers no host escolhido.
- Verificação da flag `multi_agent` do Codex, com confirmação humana antes de escrever
  na configuração global do usuário.
- Migração das regras de `CLAUDE.md` para `AGENTS.md`.
- Registro do host escolhido em `docs/engineering/PROJECT_PROFILE.md` e dos papéis por
  host em `docs/engineering/AGENT_CATALOG.md`, durante a entrevista.
- Remoção das referências a um host específico no conteúdo dos perfis, hoje presentes
  em `.agents/profiles/dependencies.md`.
- Substituição da regra de neutralidade do validador por uma regra de simetria.
- Documentação e ADR.
- Testes de bootstrap para os dois hosts com binários falsos, em `bash` e em
  PowerShell.

## Fora do escopo

- `.claude/settings.json` e `.codex/config.toml` com política de permissões e sandbox
  no repositório. As regras de autoridade continuam valendo apenas pelo texto de
  `AGENTS.md`.
- Comandos de projeto invocáveis, como `/iniciar-tarefa`.
- Suporte a hosts além de Claude Code e Codex.
- Verificação de sincronia dos arquivos gerados dentro de `validate_template.py`. A
  checagem existe, mas como modo próprio do gerador.

## Requisitos funcionais

- RF1: `.agents/roles.json` descreve os 8 papéis com os campos `name`, `description`,
  `profile`, `write`, `shell`, `custo` e `instrucao`.
- RF2: `scripts/gerar_agentes.py` gera `.claude/agents/*.md` e `.codex/agents/*.toml` a
  partir do RF1, usando apenas a biblioteca padrão do Python.
- RF3: `scripts/gerar_agentes.py --check` termina com código diferente de zero se algum
  arquivo gerado divergir do manifesto, sem escrever nada.
- RF4: todo arquivo gerado começa com um aviso de que é gerado e não deve ser editado à
  mão.
- RF5: o bootstrap resolve o host nesta ordem: flag `--host`, variável `AGENTIC_HOST`,
  detecção dos binários.
- RF6: com os dois binários presentes e sem escolha explícita, o bootstrap pergunta;
  sem terminal interativo, encerra com código 2 pedindo `--host`.
- RF7: sem nenhum binário, o bootstrap sai com código 2, não altera nada e mostra as
  instruções oficiais de instalação dos dois hosts.
- RF8: o bootstrap instala o Superpowers no host escolhido e não reinstala quando já
  presente.
- RF9: falha na instalação do Superpowers encerra com código 3 sem abrir a entrevista.
- RF10: no Codex, o bootstrap detecta a ausência de `[features] multi_agent = true` em
  `~/.codex/config.toml`, explica a consequência e só escreve após confirmação.
- RF11: o bootstrap abre a entrevista com o mesmo prompt em português do Brasil nos
  dois hosts.
- RF12: `AGENTS.md` passa a conter a regra de idioma, a regra de primeira execução e a
  regra de uso de subagentes.
- RF13: `validate_template.py` exige simetria de host e deixa de proibir a string
  `codex`.
- RF14: `prompts/INICIAR_PROJETO.md` registra o host usado na entrevista em
  `docs/engineering/PROJECT_PROFILE.md` e os papéis ativos por host em
  `docs/engineering/AGENT_CATALOG.md`.
- RF15: nenhum arquivo de `.agents/` cita um host específico como obrigatório. A
  menção a plugins e MCPs em `.agents/profiles/dependencies.md` passa a ser neutra.
- RF16: `tests/test_bootstrap.ps1` cobre no `iniciar.ps1` os mesmos casos que
  `tests/test_bootstrap.sh` cobre no `iniciar.sh`.

## Requisitos não funcionais

- Scripts Python restritos à biblioteca padrão.
- Scripts de shell compatíveis com `bash` e com PowerShell 5.1.
- A seleção explícita de host usa `--host` no `bash` e `-Assistente` no PowerShell.
  `-Host` é proibido: `$Host` é variável automática somente-leitura do PowerShell e
  declará-la como parâmetro quebra o script em execução.
- Arquivos `.ps1` gravados com BOM UTF-8, preservando a correção do commit 39c2000.
- Nenhuma escrita fora do repositório sem confirmação humana.
- Mensagens de usuário em português do Brasil.

## Arquitetura e fluxo

```text
.agents/roles.json                (fonte única)
        |
scripts/gerar_agentes.py          (stdlib; escrita ou --check)
        |
   +----+------------------------+
   |                             |
.claude/agents/<papel>.md    .codex/agents/<papel>.toml
   |                             |
Claude Code                   Codex
```

Fluxo do bootstrap:

```text
resolver host -> garantir Superpowers -> (Codex) checar multi_agent -> abrir entrevista
```

## Contratos e dados

Entrada de `.agents/roles.json`:

| Campo | Tipo | Significado |
|---|---|---|
| `name` | string | identificador do papel nos dois hosts |
| `description` | string | quando o host deve acionar o papel |
| `profile` | string | caminho do perfil em `.agents/profiles/` |
| `write` | booleano | o papel altera arquivos |
| `shell` | booleano | o papel executa comandos |
| `custo` | `economico` ou `equilibrado` | intenção de custo do papel |
| `instrucao` | string | corpo da instrução do papel, idêntico nos dois hosts |

Derivação para os dois hosts:

| Conceito | Claude | Codex |
|---|---|---|
| leitura | `tools: Read, Grep, Glob` | `sandbox_mode = "read-only"` |
| leitura com shell | `tools: Read, Grep, Glob, Bash` | `sandbox_mode = "read-only"` |
| escrita | acrescenta `Edit, Write` | `sandbox_mode = "workspace-write"` |
| econômico | `model: haiku` | `model_reasoning_effort = "low"` |
| equilibrado | `model: sonnet` | `model_reasoning_effort = "medium"` |

Nomes de modelo do fornecedor OpenAI não são fixados no template. O lado Codex
expressa a intenção de custo por esforço de raciocínio.

Contrato de saída do bootstrap:

| Código | Significado |
|---|---|
| 0 | entrevista aberta |
| 2 | host não determinado, indisponível ou argumento inválido; nada alterado |
| 3 | Superpowers não pôde ser instalado |

## Erros e casos de borda

- Host indicado por `--host` não instalado: erro explícito, sem cair para o outro host.
- `~/.codex/config.toml` inexistente: o bootstrap propõe criar o arquivo mínimo.
- Confirmação negada na escrita de `multi_agent`: a entrevista abre mesmo assim, com
  aviso de que o despacho de subagentes ficará indisponível.
- Subcomandos de plugin do Codex com formato diferente do documentado: mensagem
  acionável com o comando manual e encerramento com código 3.
- Uso de `-Host` como parâmetro no PowerShell: proibido pelo requisito não funcional
  correspondente; o nome no PowerShell é `-Assistente`.
- Dois hosts presentes sem terminal interativo, como em automação: encerra com código 2
  e instrui o uso de `--host`, em vez de escolher sozinho.
- Arquivo gerado editado à mão: detectado por `--check`.
- Papel presente em um diretório de agentes e ausente no outro: reprovado pelo
  validador.

## Segurança e privacidade

- Nenhuma credencial, token ou dado pessoal é lido, gravado ou registrado em log.
- A única escrita fora do repositório é `~/.codex/config.toml`, condicionada a
  confirmação humana e limitada à chave `features.multi_agent`.
- Papéis de revisão e exploração permanecem sem permissão de escrita nos dois hosts.
- Instalação de plugin usa apenas os marketplaces oficiais dos dois fornecedores.

## Alternativas avaliadas

1. Manter os dois conjuntos de subagentes à mão. Rejeitada: divergência silenciosa de
   conteúdo a cada mudança de papel.
2. Não criar subagentes no Codex e tratar `ROUTING.md` como instrução textual.
   Rejeitada: elimina o isolamento de contexto e o roteamento de modelo econômico, que
   é a economia de tokens do template.
3. Scripts de bootstrap separados por host. Rejeitada: dobra o número de scripts e
   duplica a lógica de instalação do Superpowers.
4. Remover a regra de neutralidade do validador. Rejeitada: o template perderia a única
   trava contra voltar a depender de um host só.

## Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Formato dos subcomandos `codex plugin` divergir do documentado | Falha com mensagem acionável e comando manual; verificação humana em máquina com Codex |
| Ausência do Codex na máquina de desenvolvimento | Testes com binário falso; validação real declarada como pendência |
| Arquivos gerados editados à mão | Cabeçalho de aviso e modo `--check` |
| `sandbox_mode` do Codex não distinguir escrita de arquivo e execução de shell | Restrição declarada em `developer_instructions` e registrada como limitação conhecida |
| Perda do BOM UTF-8 nos arquivos PowerShell | Verificação dos bytes iniciais nos testes |
| Divergência de comportamento entre `iniciar.sh` e `iniciar.ps1` | Os dois testes cobrem os mesmos cinco casos, com os mesmos códigos de saída |

## Limitações conhecidas

- O Codex expressa permissão por `sandbox_mode`, sem lista de ferramentas, e a
  divergência corre nos dois sentidos. Papéis que no Claude escrevem arquivos mas não
  executam shell, como o documentador, recebem `workspace-write` no Codex e ficam com a
  restrição de shell apenas no texto das instruções. Papéis que no Claude não têm shell
  algum, como o explorador, recebem `read-only` no Codex, que permite executar comandos
  sem escrever arquivos. Nos dois casos a garantia efetiva é a instrução, não o sandbox.
- O suporte a Codex nasce verificado por teste com binário falso. A execução real é
  pendência registrada.

## Critérios de aceite verificáveis

- CA1: `python scripts/validate_template.py` aprova.
- CA2: `python scripts/gerar_agentes.py --check` aprova com a árvore limpa.
- CA3: `bash tests/test_bootstrap.sh` aprova, cobrindo só claude, só codex, os dois com
  `--host`, nenhum dos dois retornando 2, e Superpowers já instalado não reinstalado.
- CA4: `.claude/agents/` e `.codex/agents/` contêm os mesmos 8 nomes.
- CA5: `AGENTS.md` contém a regra de idioma em português do Brasil.
- CA6: `iniciar.ps1` começa com os bytes `EF BB BF`.
- CA7: o README descreve os dois hosts com o mesmo comando de entrada, e a seção
  "Verificar o template" descreve a regra de simetria, não a regra antiga de proibição.
- CA8: nenhuma regra de processo existe apenas em `CLAUDE.md`.
- CA9: `tests/test_bootstrap.ps1` aprova, com os mesmos cinco casos do teste `bash`.
- CA10: nenhum arquivo de `.agents/` nomeia um host como obrigatório.
- CA11: `PROJECT_PROFILE.md` e `AGENT_CATALOG.md` têm campo para o host em uso.

## Validação humana

Pendente e obrigatória: executar `./iniciar.sh` em máquina com Codex instalado e
confirmar a instalação do Superpowers, o aviso de `multi_agent` e a abertura da
entrevista. Enquanto essa evidência não existir, o suporte a Codex fica registrado como
verificado por teste com binário falso, não em execução real.

## Aprovação

- Aprovador: rafaelMartins1995
- Evidência da aprovação: aprovação explícita na sessão de 2026-09-02, sobre a versão
  com RF1 a RF16 e CA1 a CA11.
