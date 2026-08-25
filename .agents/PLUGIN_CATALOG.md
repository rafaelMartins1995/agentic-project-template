# Catálogo de capacidades

O catálogo separa método, agentes e ferramentas. A entrevista registra apenas o conjunto necessário para o projeto.

| Capacidade | Categoria | Quando usar | Política |
|---|---|---|---|
| Superpowers | Plugin de método | Brainstorming, SPEC, plano, TDD, debugging, revisão e verificação | Obrigatório; instalado pelo bootstrap |
| Subagentes especializados | Agentes | Exploração, implementação, testes e revisão com contexto isolado | Ativar por tarefa e escopo |
| Navegador automatizado | Ferramenta ou MCP | Fluxos reais de interface, acessibilidade e smoke tests | Recomendado para React; requer autorização para ações externas |
| Runner local de testes | Ferramenta | Feedback rápido e regressão | Obrigatório antes de concluir mudanças |
| Integração GitHub | Ferramenta ou MCP | Issues, pull requests e checks | Opcional; selecionar na entrevista |
| Integração Azure DevOps | Ferramenta ou MCP | Work items, pull requests e pipelines | Opcional; selecionar na entrevista |
| Scanner de segurança | Ferramenta | Dependências, segredos e análise estática | Propor conforme risco; nunca enviar segredos |
| Observabilidade | Ferramenta ou MCP | Diagnóstico com logs, erros e métricas | Somente com acesso autorizado e dados minimizados |

## Regras de instalação

- Instalar automaticamente apenas o Superpowers.
- Registrar ferramentas opcionais em `docs/engineering/TOOLING.md` antes de instalar.
- Pedir autorização para dependências de produção, autenticação, escrita externa ou custos.
- Preferir ferramentas locais para lint, testes e build.
- Usar subagentes e roteamento de modelo para economizar contexto; isso não depende de plugin adicional.
