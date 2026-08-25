# Protocolo de comunicação

## Pedido do agente principal para um subagente

Cada pedido deve conter:

```md
## Objetivo

## Contexto mínimo

## Escopo permitido

## Restrições

## Saída esperada

## Critérios de conclusão
```

## Retorno do subagente

Cada retorno deve conter:

```md
## Fatos observados

## Resultado

## Evidências

## Riscos ou incertezas

## Próxima decisão necessária
```

## Regras

- Diferenciar observação, inferência e recomendação.
- Citar arquivos e comandos relevantes.
- Não aumentar o escopo silenciosamente.
- Não declarar sucesso sem verificação recente.
- Não incluir conteúdo irrelevante no contexto do agente principal.
- Interromper e devolver o controle quando faltar uma decisão humana.
