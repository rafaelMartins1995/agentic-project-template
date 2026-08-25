# Roteamento de trabalho

Use o menor número de agentes capaz de produzir evidência confiável.

| Situação | Papel preferido | Perfil de custo | Escrita | Saída esperada |
|---|---|---|---:|---|
| Localizar arquivos, contratos e padrões | Explorador | Econômico | Não | Mapa curto com referências |
| Implementar interface React aprovada | Engenheiro frontend | Equilibrado | Sim | Mudança, testes e evidências |
| Implementar API FastAPI aprovada | Engenheiro backend | Equilibrado | Sim | Mudança, testes e evidências |
| Criar ou ampliar testes | Engenheiro de testes | Equilibrado | Sim | Cenários, testes e comandos |
| Revisar comportamento e manutenção | Revisor de código | Equilibrado | Não | Achados por severidade |
| Revisar riscos de segurança | Revisor de segurança | Equilibrado | Não | Ameaças, evidências e mitigação |
| Atualizar documentação factual | Documentador | Econômico | Somente docs | Documento e fontes |

## Economia de contexto e tokens

- Delegar buscas volumosas ao Explorador e receber apenas o resumo necessário.
- Usar o Documentador para consolidação mecânica de evidências.
- Manter decisões e integração no agente principal.
- Não enviar o histórico inteiro quando objetivo, arquivos e critérios bastarem.
- Não abrir subagentes para uma tarefa curta, sequencial ou fortemente acoplada.
- Paralelizar apenas leituras ou trabalhos em arquivos independentes.

## Seleção por preset

- `backend-fastapi`: o Engenheiro backend é o implementador principal; frontend fica desativado salvo mudança aprovada de escopo.
- `frontend-react`: o Engenheiro frontend é o implementador principal; backend fica desativado salvo mudança aprovada de escopo.
