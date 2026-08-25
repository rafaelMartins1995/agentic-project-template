# Instruções do repositório

Estas regras valem para o agente principal, subagentes e qualquer execução local ou em nuvem.

## Leitura obrigatória

Antes de propor ou executar trabalho, leia:

1. `docs/engineering/PROJECT_PROFILE.md`;
2. `docs/engineering/EXECUTION_CHECKLIST.md`;
3. a SPEC e o plano da tarefa ativa;
4. `.agents/ROUTING.md` e o perfil aplicável.

## Gate de inicialização

Enquanto `PROJECT_PROFILE.md` estiver com status `NÃO INICIALIZADO`:

- não criar nem alterar código do produto;
- conduzir `prompts/INICIAR_PROJETO.md`;
- criar apenas documentos, diretórios vazios e configuração de processo;
- só marcar `PRONTO PARA PRIMEIRA TAREFA` depois da aprovação humana da primeira SPEC e do primeiro plano.

## Gate obrigatório de tarefa

Nenhuma implementação pode começar sem:

- SPEC completa e explicitamente aprovada;
- plano completo e explicitamente aprovado;
- critérios de aceite verificáveis;
- riscos, dependências e comandos de validação registrados;
- checklist apontando a próxima ação autorizada.

Se um item estiver ausente, pare a implementação e complete o documento correspondente.

## Método de trabalho

- Aplicar Superpowers quando houver uma skill compatível.
- Usar TDD para features e correções: vermelho, verde e refatoração.
- Investigar causas antes de corrigir bugs.
- Preferir mudanças pequenas, reversíveis e dentro do escopo aprovado.
- Executar testes focados antes da regressão proporcional ao risco.
- Declarar conclusão somente com evidência recente.
- Preservar alterações preexistentes e recursos protegidos.
- Nunca registrar segredos, tokens, credenciais ou dados pessoais desnecessários.

## Agente principal e subagentes

- O agente principal mantém contexto, decisões, integração e resposta final.
- Delegar apenas tarefas independentes, delimitadas e com saída definida.
- Usar agentes de leitura com modelo econômico para exploração e documentação simples.
- Não permitir escrita concorrente nos mesmos arquivos.
- Revisar toda saída delegada antes de incorporá-la.
- Não delegar decisões de produto, aceite de risco ou aprovações humanas.

## Comunicação

Toda delegação deve informar: objetivo, contexto mínimo, arquivos permitidos, restrições, saída esperada e critérios de conclusão.

Todo retorno deve separar: fatos observados, alterações realizadas, testes executados, riscos e pendências.

## Autoridade

- Leitura e testes locais compatíveis com a tarefa são permitidos.
- Dependência de produção, commit, push, PR, deploy, infraestrutura e ações externas exigem autorização explícita e separada.
- Nunca interpretar aprovação da SPEC ou do plano como autorização para commit, push ou deploy.
