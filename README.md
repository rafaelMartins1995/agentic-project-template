# Template de engenharia com agentes

Ponto de partida para projetos **Backend Python/FastAPI** ou **Frontend React/TypeScript**. A inicialização instala o plugin Superpowers no Claude Code e abre uma entrevista guiada em português do Brasil.

Ao final da entrevista, o repositório terá:

- perfil, regras e arquitetura do projeto;
- catálogo de agentes e ferramentas autorizadas;
- estrutura vazia do preset escolhido;
- primeira SPEC completa e aprovada;
- plano de execução completo e aprovado;
- checklist liberando a primeira tarefa.

Nenhum código do produto é criado durante a inicialização.

## Iniciar

Clone ou crie um repositório a partir deste template e execute um único comando na raiz.

Consulte `docs/USAR_COMO_TEMPLATE.md` para publicar a base no GitHub ou importá-la no Azure DevOps.

### macOS ou Linux

```bash
./iniciar.sh
```

### Windows

No Prompt de Comando:

```bat
iniciar.cmd
```

Ou no PowerShell:

```powershell
.\iniciar.ps1
```

Se o comando `claude` não estiver disponível, o bootstrap mostra as instruções oficiais de instalação e termina sem instalar o Superpowers nem iniciar a entrevista.

## O que o bootstrap faz

1. Verifica se o Claude Code está instalado.
2. Garante que o Superpowers esteja instalado pelo marketplace oficial do Claude.
3. Abre uma sessão interativa chamada `setup-projeto`.
4. Instrui o agente a conduzir a entrevista em `prompts/INICIAR_PROJETO.md`.

O Superpowers é instalado no escopo do usuário. A estrutura e os documentos criados pela entrevista ficam apenas neste repositório.

## Fluxo obrigatório depois da configuração

Toda tarefa que altera o produto deve seguir esta ordem:

1. SPEC completa;
2. aprovação humana da SPEC;
3. plano completo;
4. aprovação humana do plano;
5. teste falhando pelo motivo esperado;
6. implementação mínima;
7. testes, revisão e evidências;
8. commit, push e deploy somente com autorizações separadas.

As regras duráveis estão em `AGENTS.md`. `CLAUDE.md` funciona somente como adaptador para o agente padrão.

Depois que a entrevista marcar o projeto como `PRONTO PARA PRIMEIRA TAREFA`, abra uma nova sessão com:

```bash
claude "Leia prompts/INICIAR_TAREFA.md e comece pela próxima ação autorizada no checklist."
```

## Estrutura principal

```text
.
├── AGENTS.md
├── CLAUDE.md
├── .agents/
│   ├── PROTOCOL.md
│   ├── ROUTING.md
│   ├── PLUGIN_CATALOG.md
│   ├── presets/
│   └── profiles/
├── .claude/agents/
├── docs/engineering/
│   ├── PROJECT_PROFILE.md
│   ├── AGENT_CATALOG.md
│   ├── TOOLING.md
│   ├── EXECUTION_CHECKLIST.md
│   ├── specs/
│   ├── plans/
│   ├── decisions/
│   ├── evidence/
│   ├── runbooks/
│   └── templates/
├── prompts/INICIAR_PROJETO.md
└── scripts/
```

## Verificar o template

```bash
python scripts/validate_template.py
```

Essa validação confirma os arquivos obrigatórios, os gates da inicialização e a ausência de referências específicas a outros agentes no conteúdo do template.

## Fontes oficiais

- [Claude Code — instalação](https://code.claude.com/docs/en/setup)
- [Claude Code — subagentes](https://code.claude.com/docs/en/sub-agents)
- [Claude Code — plugins](https://code.claude.com/docs/en/discover-plugins)
- [Superpowers](https://github.com/obra/superpowers)
- [AGENTS.md](https://agents.md/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
