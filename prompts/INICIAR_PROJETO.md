# Entrevista de inicialização do projeto

## Missão

Personalizar este repositório até deixá-lo pronto para iniciar a primeira tarefa. Produzir documentos e diretórios vazios, sem criar código do produto nem instalar dependências da stack.

## Regras da entrevista

1. Responder em português do Brasil.
2. Confirmar que o Superpowers está ativo e usar `brainstorming` durante a descoberta e `writing-plans` ao preparar o plano.
3. Ler `AGENTS.md`, `.agents/` e os templates em `docs/engineering/templates/`.
4. Perguntar uma coisa por vez e esperar a resposta.
5. Preferir escolhas curtas quando houver opções mutuamente exclusivas.
6. Não repetir perguntas já respondidas na sessão.
7. Não inventar fatos; registrar lacunas como `A confirmar`.
8. Recapitular cada fase e pedir correção antes de continuar.
9. Não criar código do produto, configuração de build, dependências ou pipelines.
10. Não declarar o projeto pronto sem aprovação explícita da SPEC e do plano.

## Fase 1 — Objetivo, usuários e escopo

Obter, nesta ordem adaptável:

- nome do projeto;
- problema e objetivo;
- usuários principais e necessidades;
- resultado observável e métricas de sucesso;
- escopo inicial;
- itens fora do escopo;
- restrições, prazos e recursos protegidos.

Recapitular e pedir confirmação.

## Fase 2 — Preset, stack e arquitetura

Pedir a escolha de exatamente um preset:

- `backend-fastapi` — Python/FastAPI;
- `frontend-react` — React/TypeScript.

Depois, ler o preset correspondente em `.agents/presets/` e perguntar somente as decisões relevantes. Cobrir:

- versões e gerenciadores planejados;
- arquitetura e fronteiras;
- dados, contratos e integrações;
- autenticação e autorização, quando aplicável;
- erros, segurança e observabilidade;
- ambientes e restrições de execução;
- estratégia de testes e comandos planejados.

Não instalar nem inicializar a stack. Recapitular e pedir confirmação.

## Fase 3 — Colaboração e ferramentas

Perguntar:

- GitHub ou Azure DevOps;
- estratégia de branch e revisão;
- responsáveis por aprovar SPEC, plano, dependências, commit, push e deploy;
- ferramentas locais necessárias;
- integrações opcionais de `.agents/PLUGIN_CATALOG.md`;
- dados ou ações que exigem autorização especial.

Propor agentes com base em `.agents/ROUTING.md`. Explicar que exploração e documentação podem usar modelos econômicos para preservar o contexto principal. Recapitular e pedir confirmação.

## Fase 4 — Primeira tarefa

Obter:

- título e objetivo;
- usuário ou fluxo beneficiado;
- comportamento atual e desejado;
- critérios de aceite verificáveis;
- casos de borda e falhas;
- requisitos de segurança, desempenho e acessibilidade;
- dependências, riscos e fora do escopo;
- validação humana esperada.

Produzir uma proposta de SPEC em blocos curtos. Revisar até receber a frase de aprovação inequívoca da pessoa responsável.

## Fase 5 — Plano

Somente depois da aprovação da SPEC:

- dividir em tarefas pequenas e ordenadas;
- identificar caminhos de arquivos esperados, mesmo que ainda não existam;
- registrar o teste que deve falhar primeiro;
- definir a implementação mínima esperada;
- indicar comandos de verificação;
- incluir checkpoints de revisão e evidências;
- não executar o plano.

Revisar até receber aprovação inequívoca.

## Fase 6 — Materialização

Depois das duas aprovações:

1. Preencher `docs/engineering/PROJECT_PROFILE.md`.
2. Preencher `docs/engineering/AGENT_CATALOG.md` com os papéis ativos e inativos.
3. Preencher `docs/engineering/TOOLING.md` com instalado, aprovado, opcional e proibido.
4. Criar `docs/engineering/specs/0001-<slug>.md` a partir do template.
5. Criar `docs/engineering/plans/0001-<slug>.md` a partir do template.
6. Atualizar `docs/engineering/EXECUTION_CHECKLIST.md` para `PRONTO PARA PRIMEIRA TAREFA`.
7. Criar somente diretórios vazios do preset escolhido, preservados por `.gitkeep`.
8. Criar o template de pull request apenas para a plataforma escolhida:
   - GitHub: `.github/PULL_REQUEST_TEMPLATE.md`;
   - Azure DevOps: `.azuredevops/pull_request_template.md`.
9. Executar `python scripts/validate_template.py`.
10. Apresentar arquivos criados, decisões, pendências e o comando sugerido para iniciar a primeira tarefa.

Não criar commit, push, pull request ou código do produto.
