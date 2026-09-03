# Paridade de host entre Claude Code e Codex — Plano de execução

> **Para quem executa:** use `superpowers:subagent-driven-development` ou
> `superpowers:executing-plans`. Os passos usam `- [ ]` para acompanhamento.

- SPEC relacionada: `docs/engineering/specs/2026-09-02-paridade-claude-codex.md`
- Status: em revisão
- Responsável: rafaelMartins1995

**Objetivo:** entregar as mesmas funcionalidades do template a quem usa Claude Code e a
quem usa Codex, a partir de uma fonte única de papéis e de um bootstrap que reconhece os
dois hosts.

**Arquitetura:** `.agents/roles.json` é a fonte única dos 8 papéis;
`scripts/gerar_agentes.py` deriva `.claude/agents/*.md` e `.codex/agents/*.toml`; os três
scripts de bootstrap resolvem o host antes de instalar o Superpowers e abrir a entrevista;
`scripts/validate_template.py` troca a proibição de fornecedor por uma exigência de
simetria.

**Stack:** Python 3 apenas com biblioteca padrão, `bash`, PowerShell 5.1.

## Restrições globais

Valem para todas as tarefas.

- Python restrito à biblioteca padrão. Nada de dependências novas.
- `iniciar.ps1` e `tests/test_bootstrap.ps1` gravados com BOM UTF-8 (`EF BB BF`).
  Regressão do commit 39c2000.
- Compatibilidade com PowerShell 5.1: sem `&&`, sem `||`, sem operador ternário, sem
  `??`. Encadeamento com `;` e `if ($?) { }`.
- `-Host` é proibido como nome de parâmetro no PowerShell. Use `-Assistente`. No `bash`
  o nome é `--host`.
- Códigos de saída do bootstrap: `0` entrevista aberta, `2` host não determinado ou
  indisponível sem nada alterado, `3` Superpowers não instalado.
- Mensagens ao usuário em português do Brasil.
- Nenhuma escrita fora do repositório sem confirmação humana. A única permitida é
  `~/.codex/config.toml`, chave `features.multi_agent`.
- **Commit exige autorização explícita e separada.** Os pontos de commit deste plano são
  sugestões de granularidade, não autorização. Pare e peça antes de cada um.

## Pré-condições

- [ ] SPEC aprovada — feito em 2026-09-02.
- [ ] **Python 3 disponível no PATH.** Hoje não está: `python`, `python3` e `python.exe`
      resolvem apenas para os atalhos da Microsoft Store e `py` não existe. Sem isso,
      CA1 e CA2 não são verificáveis e as Tarefas 1 e 2 não podem ser testadas.
      Verificar com `python --version`, que deve imprimir `Python 3.x`.
- [ ] Baseline conhecida: `bash tests/test_bootstrap.sh` imprime `BOOTSTRAP APROVADO`.
- [ ] `codex` indisponível nesta máquina. Todo o caminho Codex nasce verificado por
      binário falso; a execução real fica como pendência declarada.

---

## Tarefa 1 — Fonte única de papéis e gerador

**Objetivo:** substituir os 8 arquivos escritos à mão por 16 arquivos gerados a partir de
um manifesto, sem alterar o comportamento dos agentes já existentes no Claude.

**Arquivos:**
- Criar: `.agents/roles.json`
- Criar: `scripts/gerar_agentes.py`
- Criar: `tests/test_gerar_agentes.py`
- Criar: `.codex/agents/{backend-engineer,code-reviewer,dependency-auditor,documenter,explorer,frontend-engineer,security-reviewer,test-engineer}.toml`
- Modificar: os 8 arquivos de `.claude/agents/` (passam a ser gerados e ganham o aviso)

**Interfaces produzidas:**
- `carregar_papeis() -> list[dict]`
- `ferramentas(papel: dict) -> str`
- `sandbox(papel: dict) -> str`
- `render_claude(papel: dict) -> str`
- `render_codex(papel: dict) -> str`
- `conteudos() -> dict[pathlib.Path, str]`
- `main(argv: list[str] | None = None) -> int`

- [ ] **Passo 1: escrever o teste que falha**

Criar `tests/test_gerar_agentes.py`:

```python
#!/usr/bin/env python3
"""Testes do gerador de subagentes; usa apenas a biblioteca padrão."""

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import gerar_agentes  # noqa: E402


class TestManifesto(unittest.TestCase):
    def test_manifesto_tem_oito_papeis(self):
        papeis = gerar_agentes.carregar_papeis()
        self.assertEqual(len(papeis), 8)

    def test_todo_papel_tem_os_campos_obrigatorios(self):
        for papel in gerar_agentes.carregar_papeis():
            for campo in ("name", "description", "profile", "write", "shell", "custo", "instrucao"):
                self.assertIn(campo, papel, f"papel {papel.get('name')} sem campo {campo}")

    def test_todo_perfil_referenciado_existe(self):
        for papel in gerar_agentes.carregar_papeis():
            self.assertTrue((ROOT / papel["profile"]).is_file(), papel["profile"])


class TestDerivacao(unittest.TestCase):
    def test_papel_somente_leitura_nao_recebe_bash_nem_escrita(self):
        papel = {"write": False, "shell": False}
        self.assertEqual(gerar_agentes.ferramentas(papel), "Read, Grep, Glob")

    def test_papel_com_shell_recebe_bash(self):
        papel = {"write": False, "shell": True}
        self.assertEqual(gerar_agentes.ferramentas(papel), "Read, Grep, Glob, Bash")

    def test_papel_que_escreve_sem_shell_nao_recebe_bash(self):
        papel = {"write": True, "shell": False}
        self.assertEqual(gerar_agentes.ferramentas(papel), "Read, Grep, Glob, Edit, Write")

    def test_papel_que_escreve_com_shell_recebe_tudo(self):
        papel = {"write": True, "shell": True}
        self.assertEqual(gerar_agentes.ferramentas(papel), "Read, Grep, Glob, Bash, Edit, Write")

    def test_sandbox_do_codex_segue_a_permissao_de_escrita(self):
        self.assertEqual(gerar_agentes.sandbox({"write": False}), "read-only")
        self.assertEqual(gerar_agentes.sandbox({"write": True}), "workspace-write")


class TestRenderizacao(unittest.TestCase):
    def papel_exemplo(self):
        return {
            "name": "explorer",
            "description": "Explora o repositório.",
            "profile": ".agents/profiles/explorer.md",
            "write": False,
            "shell": False,
            "custo": "economico",
            "instrucao": "Leia o perfil e retorne um mapa curto.",
        }

    def test_claude_recebe_frontmatter_com_modelo_economico(self):
        texto = gerar_agentes.render_claude(self.papel_exemplo())
        self.assertTrue(texto.startswith("---\n"))
        self.assertIn("name: explorer\n", texto)
        self.assertIn("tools: Read, Grep, Glob\n", texto)
        self.assertIn("model: haiku\n", texto)
        self.assertIn("ARQUIVO GERADO", texto)
        self.assertIn("Leia o perfil e retorne um mapa curto.", texto)

    def test_aviso_do_claude_vem_depois_do_frontmatter(self):
        texto = gerar_agentes.render_claude(self.papel_exemplo())
        self.assertLess(texto.index("---\n"), texto.index("ARQUIVO GERADO"))
        self.assertLess(texto.index("model: haiku"), texto.index("ARQUIVO GERADO"))

    def test_codex_recebe_sandbox_e_esforco(self):
        texto = gerar_agentes.render_codex(self.papel_exemplo())
        self.assertIn('name = "explorer"', texto)
        self.assertIn('sandbox_mode = "read-only"', texto)
        self.assertIn('model_reasoning_effort = "low"', texto)
        self.assertIn("developer_instructions", texto)
        self.assertIn("ARQUIVO GERADO", texto)

    def test_codex_nao_fixa_nome_de_modelo(self):
        texto = gerar_agentes.render_codex(self.papel_exemplo())
        self.assertNotIn("model =", texto)

    def test_papel_equilibrado_usa_sonnet_e_medium(self):
        papel = dict(self.papel_exemplo(), custo="equilibrado")
        self.assertIn("model: sonnet\n", gerar_agentes.render_claude(papel))
        self.assertIn('model_reasoning_effort = "medium"', gerar_agentes.render_codex(papel))


class TestSincronia(unittest.TestCase):
    def test_arquivos_em_disco_batem_com_o_manifesto(self):
        divergentes = [
            str(caminho.relative_to(ROOT))
            for caminho, conteudo in gerar_agentes.conteudos().items()
            if not caminho.is_file() or caminho.read_text(encoding="utf-8") != conteudo
        ]
        self.assertEqual(divergentes, [], "regenere com: python scripts/gerar_agentes.py")

    def test_check_retorna_zero_com_a_arvore_sincronizada(self):
        self.assertEqual(gerar_agentes.main(["--check"]), 0)

    def test_os_dois_hosts_recebem_os_mesmos_nomes(self):
        nomes_claude = {c.stem for c in gerar_agentes.conteudos() if c.suffix == ".md"}
        nomes_codex = {c.stem for c in gerar_agentes.conteudos() if c.suffix == ".toml"}
        self.assertEqual(nomes_claude, nomes_codex)
        self.assertEqual(len(nomes_claude), 8)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Passo 2: rodar e confirmar a falha**

Comando: `python -m unittest discover -s tests -p "test_*.py" -v`

Falha esperada: `ModuleNotFoundError: No module named 'gerar_agentes'`.

- [ ] **Passo 3: escrever o manifesto**

Criar `.agents/roles.json`. Os campos `description` e `instrucao` são cópia literal do
que hoje está em `.claude/agents/*.md`, para que a mudança não altere comportamento:

```json
[
  {
    "name": "explorer",
    "description": "Explora o repositório em modo somente leitura para localizar arquivos, contratos, dependências e padrões. Use antes de planejar mudanças ou quando buscas volumosas poluiriam o contexto principal.",
    "profile": ".agents/profiles/explorer.md",
    "write": false,
    "shell": false,
    "custo": "economico",
    "instrucao": "Leia `.agents/profiles/explorer.md` e `.agents/PROTOCOL.md`. Trabalhe somente no escopo recebido. Retorne um mapa curto e verificável; não altere arquivos."
  },
  {
    "name": "dependency-auditor",
    "description": "Diagnostica dependências de linguagem (Python/Node) ausentes, desatualizadas ou incompatíveis e recomenda o comando de instalação exato. Nunca instala nem edita arquivos. Use ao esbarrar em erro de dependência durante a implementação ou para checar o ambiente no início de uma tarefa aprovada.",
    "profile": ".agents/profiles/dependencies.md",
    "write": false,
    "shell": true,
    "custo": "economico",
    "instrucao": "Leia `.agents/profiles/dependencies.md` e `.agents/PROTOCOL.md`. Compare os manifestos de dependência com o ambiente instalado e retorne apenas diagnóstico e comando recomendado. Nunca execute instalação, nunca edite arquivos."
  },
  {
    "name": "documenter",
    "description": "Atualiza documentação factual, decisões, runbooks e evidências, mantendo resultados não confirmados marcados como pendentes.",
    "profile": ".agents/profiles/documenter.md",
    "write": true,
    "shell": false,
    "custo": "economico",
    "instrucao": "Leia `.agents/profiles/documenter.md` e `.agents/PROTOCOL.md`. Altere somente documentação e não invente resultados. Não execute comandos."
  },
  {
    "name": "backend-engineer",
    "description": "Implementa planos aprovados em projetos Python e FastAPI. Use somente quando o preset backend-fastapi estiver ativo e a SPEC e o plano estiverem aprovados.",
    "profile": ".agents/profiles/backend.md",
    "write": true,
    "shell": true,
    "custo": "equilibrado",
    "instrucao": "Leia `.agents/profiles/backend.md`, `.agents/PROTOCOL.md`, a SPEC e o plano ativos. Execute apenas a tarefa delimitada, aplique TDD e retorne testes e evidências."
  },
  {
    "name": "frontend-engineer",
    "description": "Implementa planos aprovados em projetos React e TypeScript. Use somente quando o preset frontend-react estiver ativo e a SPEC e o plano estiverem aprovados.",
    "profile": ".agents/profiles/frontend.md",
    "write": true,
    "shell": true,
    "custo": "equilibrado",
    "instrucao": "Leia `.agents/profiles/frontend.md`, `.agents/PROTOCOL.md`, a SPEC e o plano ativos. Execute apenas a tarefa delimitada, aplique TDD e retorne testes e evidências."
  },
  {
    "name": "test-engineer",
    "description": "Converte critérios de aceite aprovados em testes e investiga lacunas de cobertura para frontend ou backend.",
    "profile": ".agents/profiles/tests.md",
    "write": true,
    "shell": true,
    "custo": "equilibrado",
    "instrucao": "Leia `.agents/profiles/tests.md` e `.agents/PROTOCOL.md`. Preserve asserções fortes, confirme a falha esperada e diferencie problemas de produto, teste e ambiente."
  },
  {
    "name": "code-reviewer",
    "description": "Revisa alterações contra a SPEC, o plano, os contratos e os testes. Use após implementação e antes de declarar conclusão.",
    "profile": ".agents/profiles/reviewer.md",
    "write": false,
    "shell": true,
    "custo": "equilibrado",
    "instrucao": "Leia `.agents/profiles/reviewer.md` e `.agents/PROTOCOL.md`. Não edite arquivos. Priorize bugs, regressões, segurança e testes; reporte evidência e severidade."
  },
  {
    "name": "security-reviewer",
    "description": "Revisa autenticação, autorização, dados, entradas, dependências e superfícies de ataque em mudanças de risco relevante.",
    "profile": ".agents/profiles/security.md",
    "write": false,
    "shell": true,
    "custo": "equilibrado",
    "instrucao": "Leia `.agents/profiles/security.md` e `.agents/PROTOCOL.md`. Não edite arquivos nem execute ações destrutivas. Minimize qualquer dado sensível no retorno."
  }
]
```

Duas instruções mudam de propósito, por causa da limitação de sandbox registrada na SPEC:
`documenter` ganha a frase "Não execute comandos", já que no Codex o `workspace-write`
não impede shell. O texto do `explorer` já cobre o caso inverso ao dizer "não altere
arquivos".

- [ ] **Passo 4: escrever o gerador**

Criar `scripts/gerar_agentes.py`:

```python
#!/usr/bin/env python3
"""Gera as definições de subagente dos hosts suportados a partir de .agents/roles.json.

Uso:
    python scripts/gerar_agentes.py            escreve os arquivos
    python scripts/gerar_agentes.py --check    apenas confere a sincronia
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFESTO = ROOT / ".agents" / "roles.json"
DESTINO_CLAUDE = ROOT / ".claude" / "agents"
DESTINO_CODEX = ROOT / ".codex" / "agents"

AVISO = (
    "ARQUIVO GERADO por scripts/gerar_agentes.py a partir de .agents/roles.json. "
    "Não edite à mão; edite o manifesto e gere de novo."
)

MODELO_CLAUDE = {"economico": "haiku", "equilibrado": "sonnet"}
ESFORCO_CODEX = {"economico": "low", "equilibrado": "medium"}

CAMPOS = ("name", "description", "profile", "write", "shell", "custo", "instrucao")


def carregar_papeis() -> list[dict]:
    papeis = json.loads(MANIFESTO.read_text(encoding="utf-8"))
    for papel in papeis:
        faltando = [campo for campo in CAMPOS if campo not in papel]
        if faltando:
            raise ValueError(f"papel {papel.get('name')!r} sem campos: {faltando}")
        if papel["custo"] not in MODELO_CLAUDE:
            raise ValueError(f"custo inválido em {papel['name']!r}: {papel['custo']!r}")
        if '"""' in papel["instrucao"]:
            raise ValueError(f"instrução de {papel['name']!r} não pode conter aspas triplas")
    return papeis


def ferramentas(papel: dict) -> str:
    tools = ["Read", "Grep", "Glob"]
    if papel["shell"]:
        tools.append("Bash")
    if papel["write"]:
        tools.extend(["Edit", "Write"])
    return ", ".join(tools)


def sandbox(papel: dict) -> str:
    return "workspace-write" if papel["write"] else "read-only"


def render_claude(papel: dict) -> str:
    return (
        "---\n"
        f"name: {papel['name']}\n"
        f"description: {papel['description']}\n"
        f"tools: {ferramentas(papel)}\n"
        f"model: {MODELO_CLAUDE[papel['custo']]}\n"
        "---\n"
        "\n"
        f"<!-- {AVISO} -->\n"
        "\n"
        f"{papel['instrucao']}\n"
    )


def render_codex(papel: dict) -> str:
    def texto(valor: str) -> str:
        return json.dumps(valor, ensure_ascii=False)

    return (
        f"# {AVISO}\n"
        f"name = {texto(papel['name'])}\n"
        f"description = {texto(papel['description'])}\n"
        f"sandbox_mode = {texto(sandbox(papel))}\n"
        f"model_reasoning_effort = {texto(ESFORCO_CODEX[papel['custo']])}\n"
        'developer_instructions = """\n'
        f"{papel['instrucao']}\n"
        '"""\n'
    )


def conteudos() -> dict[Path, str]:
    saida: dict[Path, str] = {}
    for papel in carregar_papeis():
        saida[DESTINO_CLAUDE / f"{papel['name']}.md"] = render_claude(papel)
        saida[DESTINO_CODEX / f"{papel['name']}.toml"] = render_codex(papel)
    return saida


def divergencias() -> list[str]:
    fora = []
    for caminho, conteudo in conteudos().items():
        atual = caminho.read_text(encoding="utf-8") if caminho.is_file() else None
        if atual != conteudo:
            fora.append(str(caminho.relative_to(ROOT)))
    return sorted(fora)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Gera os subagentes dos hosts suportados.")
    parser.add_argument("--check", action="store_true", help="confere sem escrever")
    args = parser.parse_args(argv)

    if args.check:
        fora = divergencias()
        if fora:
            print("SINCRONIA FALHOU")
            for caminho in fora:
                print(f"- {caminho}")
            print("Regenere com: python scripts/gerar_agentes.py")
            return 1
        print("SINCRONIA APROVADA")
        return 0

    for caminho, conteudo in conteudos().items():
        caminho.parent.mkdir(parents=True, exist_ok=True)
        caminho.write_text(conteudo, encoding="utf-8", newline="\n")
    print(f"Arquivos gerados: {len(conteudos())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Passo 5: gerar os arquivos**

Comando: `python scripts/gerar_agentes.py`

Esperado: `Arquivos gerados: 16`.

- [ ] **Passo 6: rodar os testes e confirmar que passam**

Comando: `python -m unittest discover -s tests -p "test_*.py" -v`

Esperado: todos os testes passam.

- [ ] **Passo 7: conferir o diff dos agentes do Claude**

Comando: `git diff --stat .claude/agents/`

Esperado: os 8 arquivos mudam apenas pela linha de aviso e, no `documenter`, pela frase
"Não execute comandos". Se algum `tools:` ou `model:` mudar, o manifesto está errado —
corrija o manifesto, não o arquivo gerado.

- [ ] **Passo 8: commit** — requer autorização explícita.

```bash
git add .agents/roles.json scripts/gerar_agentes.py tests/test_gerar_agentes.py .claude/agents .codex/agents
git commit -m "Cria fonte unica de papeis e gera subagentes para os dois hosts"
```

**Evidência a registrar:** saída de `python -m unittest` e de `git diff --stat`.

---

## Tarefa 2 — Validador de simetria

**Objetivo:** trocar a regra que proíbe citar um fornecedor por uma regra que exige que os
dois hosts sejam tratados igual. Esta tarefa falha de propósito ao final: são as Tarefas 3
a 6 que a fazem passar.

**Arquivos:**
- Modificar: `scripts/validate_template.py:13-39` (lista `REQUIRED`)
- Modificar: `scripts/validate_template.py:73-83` (`validate_vendor_neutrality`)
- Modificar: `scripts/validate_template.py:86-91` (`main`)

**Interfaces consumidas:** `.agents/roles.json` e `.codex/agents/*.toml` da Tarefa 1.

**Interfaces produzidas:** `validate_host_symmetry(errors: list[str]) -> None`.

- [ ] **Passo 1: ampliar a lista de arquivos obrigatórios**

Em `REQUIRED`, depois de `".claude/agents/documenter.md"`, acrescentar:

```python
    ".agents/roles.json",
    "scripts/gerar_agentes.py",
    "tests/test_gerar_agentes.py",
    "tests/test_bootstrap.sh",
    "tests/test_bootstrap.ps1",
    ".codex/agents/explorer.toml",
    ".codex/agents/frontend-engineer.toml",
    ".codex/agents/backend-engineer.toml",
    ".codex/agents/test-engineer.toml",
    ".codex/agents/code-reviewer.toml",
    ".codex/agents/security-reviewer.toml",
    ".codex/agents/documenter.toml",
    ".codex/agents/dependency-auditor.toml",
```

- [ ] **Passo 2: substituir a regra de neutralidade**

Remover `validate_vendor_neutrality` inteira e pôr no lugar:

```python
HOSTS = ("claude", "codex")

CAMPOS_CODEX = ("name", "description", "sandbox_mode", "developer_instructions")


def validate_host_symmetry(errors: list[str]) -> None:
    nomes = {}
    for host, diretorio, sufixo in (
        ("claude", ROOT / ".claude" / "agents", ".md"),
        ("codex", ROOT / ".codex" / "agents", ".toml"),
    ):
        nomes[host] = {p.stem for p in diretorio.glob(f"*{sufixo}")}

    if nomes["claude"] != nomes["codex"]:
        so_claude = sorted(nomes["claude"] - nomes["codex"])
        so_codex = sorted(nomes["codex"] - nomes["claude"])
        if so_claude:
            errors.append(f"Papéis ausentes em .codex/agents: {so_claude}")
        if so_codex:
            errors.append(f"Papéis ausentes em .claude/agents: {so_codex}")

    for path in sorted((ROOT / ".codex" / "agents").glob("*.toml")):
        texto = path.read_text(encoding="utf-8")
        for campo in CAMPOS_CODEX:
            if not re.search(rf"^{campo}\s*=", texto, flags=re.MULTILINE):
                errors.append(f"Campo '{campo}' ausente: {path.relative_to(ROOT)}")

    readme = (ROOT / "README.md").read_text(encoding="utf-8").casefold()
    for host in HOSTS:
        if host not in readme:
            errors.append(f"README não descreve o host: {host}")

    for nome in ("iniciar.sh", "iniciar.ps1"):
        texto = (ROOT / nome).read_text(encoding="utf-8").casefold()
        for host in HOSTS:
            if host not in texto:
                errors.append(f"{nome} não reconhece o host: {host}")


def validate_neutral_content(errors: list[str]) -> None:
    marcas = ("claude code", "codex")
    for path in sorted((ROOT / ".agents").rglob("*.md")):
        texto = path.read_text(encoding="utf-8").casefold()
        for marca in marcas:
            if marca in texto:
                errors.append(
                    f"Referência a host específico em: {path.relative_to(ROOT)} ({marca})"
                )


def validate_language_rule(errors: list[str]) -> None:
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    if "português do Brasil" not in agents:
        errors.append("AGENTS.md não fixa o idioma de resposta")
    if "prompts/INICIAR_PROJETO.md" not in agents:
        errors.append("AGENTS.md não aponta a entrevista de primeira execução")
```

- [ ] **Passo 3: ligar as funções ao `main`**

Trocar a chamada de `validate_vendor_neutrality(errors)` por:

```python
    validate_host_symmetry(errors)
    validate_neutral_content(errors)
    validate_language_rule(errors)
```

E, no bloco de sucesso, trocar a linha `print("Presets: ...")` por:

```python
    print("Presets: backend-fastapi, frontend-react")
    print("Hosts com paridade: claude, codex")
```

- [ ] **Passo 4: rodar e confirmar a falha esperada**

Comando: `python scripts/validate_template.py`

Falha esperada, e apenas esta lista:
- `tests/test_bootstrap.ps1` ausente (Tarefa 5);
- `iniciar.sh` e `iniciar.ps1` não reconhecem `codex` (Tarefas 4 e 5);
- `README não descreve o host: codex` (Tarefa 6);
- referência a host específico em `.agents/profiles/dependencies.md` (Tarefa 3);
- `AGENTS.md não fixa o idioma de resposta` (Tarefa 3).

Se aparecer erro fora dessa lista, pare e investigue antes de seguir.

- [ ] **Passo 5: commit** — requer autorização explícita.

```bash
git add scripts/validate_template.py
git commit -m "Troca proibicao de fornecedor por exigencia de simetria entre hosts"
```

**Evidência a registrar:** saída de `validate_template.py` com exatamente os cinco erros
previstos.

---

## Tarefa 3 — Instruções, idioma e registro do host

**Objetivo:** garantir que as regras de processo cheguem inteiras aos dois hosts e que o
host usado fique registrado nos documentos do projeto.

**Arquivos:**
- Modificar: `AGENTS.md`
- Modificar: `CLAUDE.md`
- Modificar: `.agents/profiles/dependencies.md:28`
- Modificar: `docs/engineering/PROJECT_PROFILE.md`
- Modificar: `docs/engineering/AGENT_CATALOG.md`
- Modificar: `docs/engineering/templates/PROJECT_PROFILE_TEMPLATE.md`
- Modificar: `docs/engineering/templates/AGENT_CATALOG_TEMPLATE.md`
- Modificar: `prompts/INICIAR_PROJETO.md`

**Interfaces consumidas:** as três funções de validação da Tarefa 2.

- [ ] **Passo 1: acrescentar a seção de idioma e primeira execução ao `AGENTS.md`**

Inserir logo após o parágrafo de abertura, antes de `## Leitura obrigatória`:

```markdown
## Idioma e primeira execução

- Responder e produzir documentos em português do Brasil.
- Na primeira execução do repositório, seguir `prompts/INICIAR_PROJETO.md` e perguntar
  uma coisa por vez.
- Usar os subagentes disponíveis no host em uso conforme `.agents/ROUTING.md`.
- Não escrever código do produto durante a entrevista inicial.
```

- [ ] **Passo 2: reduzir o `CLAUDE.md` a adaptador**

Substituir o conteúdo inteiro por:

```markdown
@AGENTS.md

# Adaptador do host

Este arquivo existe apenas para que o host que lê `CLAUDE.md` carregue o `AGENTS.md`.
Todas as regras do projeto vivem no `AGENTS.md`. Não acrescente regra aqui: outro host
não vai lê-la.
```

- [ ] **Passo 3: neutralizar o perfil de dependências**

Em `.agents/profiles/dependencies.md`, trocar a última linha de `## Limites`:

```diff
-- Escopo restrito a dependências de linguagem (Python/Node); não cobre CLIs externas nem plugins/MCPs do Claude Code.
+- Escopo restrito a dependências de linguagem (Python/Node); não cobre CLIs externas nem plugins e MCPs do host em uso.
```

- [ ] **Passo 4: criar o campo de host no perfil do projeto**

Em `docs/engineering/PROJECT_PROFILE.md`, acrescentar após a linha de status:

```markdown
**Host de agente em uso:** A confirmar na entrevista
```

Repetir a mesma linha em `docs/engineering/templates/PROJECT_PROFILE_TEMPLATE.md`, na
posição equivalente.

- [ ] **Passo 5: criar o campo de host no catálogo de agentes**

Em `docs/engineering/AGENT_CATALOG.md`, acrescentar após a linha de status:

```markdown
**Host de agente em uso:** A confirmar na entrevista

Os papéis são definidos em `.agents/roles.json` e gerados para os dois hosts por
`scripts/gerar_agentes.py`. Este catálogo registra quais estão ativos no projeto.
```

Acrescentar as mesmas duas informações em
`docs/engineering/templates/AGENT_CATALOG_TEMPLATE.md`.

- [ ] **Passo 6: mandar a entrevista registrar o host**

Em `prompts/INICIAR_PROJETO.md`, na Fase 6, trocar os itens 1 e 2 por:

```markdown
1. Preencher `docs/engineering/PROJECT_PROFILE.md`, incluindo o host de agente em uso.
2. Preencher `docs/engineering/AGENT_CATALOG.md` com os papéis ativos e inativos e com o
   host de agente em uso.
```

E, na mesma fase, inserir um item novo entre o atual 8 e o atual 9:

```markdown
9. Executar `python scripts/gerar_agentes.py --check` e regenerar se houver divergência.
```

Renumerar os itens seguintes.

- [ ] **Passo 7: rodar o validador**

Comando: `python scripts/validate_template.py`

Esperado: somem os erros de `dependencies.md` e de idioma. Continuam os três de bootstrap
e README, que são das Tarefas 4 a 6.

- [ ] **Passo 8: commit** — requer autorização explícita.

```bash
git add AGENTS.md CLAUDE.md .agents/profiles/dependencies.md docs/engineering prompts/INICIAR_PROJETO.md
git commit -m "Move regras de processo para AGENTS.md e registra host nos documentos"
```

**Evidência a registrar:** saída do validador antes e depois, mostrando os dois erros que
sumiram.

---

## Tarefa 4 — Bootstrap bash com dois hosts

**Objetivo:** `iniciar.sh` resolve o host, instala o Superpowers nele e abre a entrevista,
mantendo o comportamento atual quando só o Claude está presente.

**Arquivos:**
- Modificar: `iniciar.sh` (reescrita)
- Modificar: `tests/test_bootstrap.sh` (casos novos)

**Interfaces produzidas:** contrato de saída `0`, `2`, `3` e as variáveis
`AGENTIC_CLAUDE_BIN`, `AGENTIC_CODEX_BIN`, `AGENTIC_HOST`.

- [ ] **Passo 1: escrever os testes que falham**

Acrescentar ao final de `tests/test_bootstrap.sh`, antes da linha
`printf '%s\n' 'BOOTSTRAP APROVADO'`:

```bash
FAKE_CODEX="$TEMP_DIR/fake-codex"
cat >"$FAKE_CODEX" <<'FAKE_CODEX_BIN'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${AGENTIC_TEST_LOG:?}"
exit 0
FAKE_CODEX_BIN
chmod +x "$FAKE_CODEX"

# Só o Codex presente: usa o Codex sem perguntar.
: >"$CALL_LOG"
AGENTIC_CLAUDE_BIN="comando-claude-inexistente" \
AGENTIC_CODEX_BIN="$FAKE_CODEX" \
AGENTIC_TEST_LOG="$CALL_LOG" "$ROOT_DIR/iniciar.sh" >/dev/null
grep -q 'plugin' "$CALL_LOG"
grep -q 'prompts/INICIAR_PROJETO.md' "$CALL_LOG"

# Os dois presentes com --host: respeita a escolha e não toca no outro.
: >"$CALL_LOG"
AGENTIC_CLAUDE_BIN="$FAKE_CLAUDE" \
AGENTIC_CODEX_BIN="$FAKE_CODEX" \
AGENTIC_TEST_LOG="$CALL_LOG" "$ROOT_DIR/iniciar.sh" --host codex >/dev/null
if grep -q -- '--name setup-projeto' "$CALL_LOG"; then
  printf '%s\n' 'Falha: --host codex não deveria acionar o Claude.' >&2
  exit 1
fi

# --host apontando para host ausente: erro explícito, sem cair no outro.
set +e
AGENTIC_CLAUDE_BIN="$FAKE_CLAUDE" \
AGENTIC_CODEX_BIN="comando-codex-inexistente" \
AGENTIC_TEST_LOG="$CALL_LOG" "$ROOT_DIR/iniciar.sh" --host codex >"$TEMP_DIR/host-ausente.log" 2>&1
host_ausente_status=$?
set -e
if [ "$host_ausente_status" -ne 2 ]; then
  printf '%s\n' "Falha: host ausente deveria retornar 2, retornou $host_ausente_status" >&2
  exit 1
fi

# Nenhum dos dois: retorna 2 e cita os dois hosts.
set +e
AGENTIC_CLAUDE_BIN="comando-claude-inexistente" \
AGENTIC_CODEX_BIN="comando-codex-inexistente" \
"$ROOT_DIR/iniciar.sh" >"$TEMP_DIR/sem-host.log" 2>&1
sem_host_status=$?
set -e
if [ "$sem_host_status" -ne 2 ]; then
  printf '%s\n' "Falha: sem host deveria retornar 2, retornou $sem_host_status" >&2
  exit 1
fi
grep -qi 'claude' "$TEMP_DIR/sem-host.log"
grep -qi 'codex' "$TEMP_DIR/sem-host.log"

# Os dois presentes, sem escolha e sem terminal: retorna 2 pedindo --host.
set +e
AGENTIC_CLAUDE_BIN="$FAKE_CLAUDE" \
AGENTIC_CODEX_BIN="$FAKE_CODEX" \
AGENTIC_TEST_LOG="$CALL_LOG" "$ROOT_DIR/iniciar.sh" </dev/null >"$TEMP_DIR/ambiguo.log" 2>&1
ambiguo_status=$?
set -e
if [ "$ambiguo_status" -ne 2 ]; then
  printf '%s\n' "Falha: empate sem terminal deveria retornar 2, retornou $ambiguo_status" >&2
  exit 1
fi
grep -q -- '--host' "$TEMP_DIR/ambiguo.log"
```

- [ ] **Passo 2: rodar e confirmar a falha**

Comando: `bash tests/test_bootstrap.sh`

Falha esperada: o primeiro caso novo já quebra, porque `iniciar.sh` ignora
`AGENTIC_CODEX_BIN` e sai com 2 ao não achar o `claude`.

- [ ] **Passo 3: reescrever o `iniciar.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_COMMAND="${AGENTIC_CLAUDE_BIN:-claude}"
CODEX_COMMAND="${AGENTIC_CODEX_BIN:-codex}"
HOST_ESCOLHIDO="${AGENTIC_HOST:-}"
HOST=""

PROMPT_ENTREVISTA="Leia prompts/INICIAR_PROJETO.md e conduza a entrevista agora. Siga AGENTS.md. Faça uma pergunta por vez, em português do Brasil. Não crie código do produto."

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST_ESCOLHIDO="${2:-}"; shift 2 ;;
    --host=*) HOST_ESCOLHIDO="${1#--host=}"; shift ;;
    *) printf '%s\n' "Argumento desconhecido: $1. Use --host claude ou --host codex." >&2; exit 2 ;;
  esac
done

tem_comando() { command -v "$1" >/dev/null 2>&1; }

instrucoes_de_instalacao() {
  printf '%s\n' \
    'Nenhum host de agente foi encontrado. Nenhuma alteração foi realizada.' \
    '' \
    'Claude Code:' \
    '  macOS/Linux: curl -fsSL https://claude.ai/install.sh | bash' \
    '  macOS/Homebrew: brew install --cask claude-code' \
    '  Documentação: https://code.claude.com/docs/en/setup' \
    '' \
    'Codex:' \
    '  npm: npm install -g @openai/codex' \
    '  macOS/Homebrew: brew install codex' \
    '  Documentação: https://developers.openai.com/codex/cli' \
    '' \
    'Depois de instalar e autenticar, execute novamente: ./iniciar.sh'
}

resolver_host() {
  local tem_claude=0 tem_codex=0
  tem_comando "$CLAUDE_COMMAND" && tem_claude=1
  tem_comando "$CODEX_COMMAND" && tem_codex=1

  if [ -n "$HOST_ESCOLHIDO" ]; then
    case "$HOST_ESCOLHIDO" in
      claude)
        if [ "$tem_claude" -eq 0 ]; then
          printf '%s\n' "Host 'claude' foi pedido, mas o comando '$CLAUDE_COMMAND' não existe. Nada alterado." >&2
          exit 2
        fi
        ;;
      codex)
        if [ "$tem_codex" -eq 0 ]; then
          printf '%s\n' "Host 'codex' foi pedido, mas o comando '$CODEX_COMMAND' não existe. Nada alterado." >&2
          exit 2
        fi
        ;;
      *)
        printf '%s\n' "Host inválido: '$HOST_ESCOLHIDO'. Use claude ou codex." >&2
        exit 2
        ;;
    esac
    HOST="$HOST_ESCOLHIDO"
    return 0
  fi

  if [ "$tem_claude" -eq 1 ] && [ "$tem_codex" -eq 0 ]; then HOST="claude"; return 0; fi
  if [ "$tem_codex" -eq 1 ] && [ "$tem_claude" -eq 0 ]; then HOST="codex"; return 0; fi
  if [ "$tem_claude" -eq 0 ] && [ "$tem_codex" -eq 0 ]; then
    instrucoes_de_instalacao
    exit 2
  fi

  if [ ! -t 0 ]; then
    printf '%s\n' 'Claude Code e Codex estão instalados e não há terminal para perguntar.' \
                  'Escolha com --host claude ou --host codex. Nada alterado.' >&2
    exit 2
  fi

  printf '%s\n' 'Os dois hosts estão instalados:' '  [1] Claude Code' '  [2] Codex'
  printf '%s' 'Qual você quer usar? [1/2] '
  read -r escolha
  case "$escolha" in
    1) HOST="claude" ;;
    2) HOST="codex" ;;
    *) printf '%s\n' 'Escolha inválida. Nada alterado.' >&2; exit 2 ;;
  esac
}

garantir_superpowers_claude() {
  printf '%s\n' 'Verificando o plugin Superpowers no Claude Code...'
  if ! "$CLAUDE_COMMAND" plugin marketplace list 2>/dev/null | grep -qi 'claude-plugins-official'; then
    printf '%s\n' 'Registrando o marketplace oficial de plugins...'
    "$CLAUDE_COMMAND" plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1 || true
  fi
  if "$CLAUDE_COMMAND" plugin list 2>/dev/null | grep -qi 'superpowers'; then
    printf '%s\n' 'Superpowers já está instalado.'
    return 0
  fi
  if ! "$CLAUDE_COMMAND" plugin install superpowers@claude-plugins-official --scope user; then
    printf '%s\n' \
      'Não foi possível instalar o Superpowers. A entrevista não será iniciada.' \
      'Verifique sua conexão e autenticação com: claude doctor' >&2
    exit 3
  fi
}

garantir_superpowers_codex() {
  printf '%s\n' 'Verificando o plugin Superpowers no Codex...'
  if ! "$CODEX_COMMAND" plugin marketplace list 2>/dev/null | grep -qi 'openai'; then
    printf '%s\n' 'Registrando o marketplace oficial de plugins...'
    "$CODEX_COMMAND" plugin marketplace add openai/plugins >/dev/null 2>&1 || true
  fi
  if "$CODEX_COMMAND" plugin list 2>/dev/null | grep -qi 'superpowers'; then
    printf '%s\n' 'Superpowers já está instalado.'
    return 0
  fi
  if ! "$CODEX_COMMAND" plugin add superpowers; then
    printf '%s\n' \
      'Não foi possível instalar o Superpowers. A entrevista não será iniciada.' \
      'Instale manualmente e tente de novo:' \
      '  codex plugin marketplace add openai/plugins' \
      '  codex plugin add superpowers' \
      'Confira os subcomandos disponíveis com: codex plugin --help' >&2
    exit 3
  fi
}

garantir_multi_agent() {
  local config="${CODEX_HOME:-$HOME/.codex}/config.toml"
  if grep -qE 'multi_agent[[:space:]]*=[[:space:]]*true' "$config" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' \
    '' \
    'O Codex precisa de [features] multi_agent = true para despachar subagentes.' \
    "Isso altera um arquivo fora do repositório: $config" \
    ''
  if [ ! -t 0 ]; then
    printf '%s\n' 'Sem terminal para confirmar. Seguindo sem alterar; os subagentes ficarão indisponíveis.'
    return 0
  fi
  printf '%s' 'Posso acrescentar essa configuração? [s/N] '
  read -r resposta
  case "$resposta" in
    s|S)
      mkdir -p "$(dirname "$config")"
      printf '\n[features]\nmulti_agent = true\n' >>"$config"
      printf '%s\n' "Configuração acrescentada em $config"
      ;;
    *)
      printf '%s\n' 'Nada alterado. Os subagentes ficarão indisponíveis nesta sessão.'
      ;;
  esac
}

cd "$ROOT_DIR"
resolver_host

if [ "$HOST" = "claude" ]; then
  garantir_superpowers_claude
  printf '%s\n' 'Abrindo a entrevista de inicialização no Claude Code...'
  exec "$CLAUDE_COMMAND" --name setup-projeto "$PROMPT_ENTREVISTA"
fi

garantir_superpowers_codex
garantir_multi_agent
printf '%s\n' 'Abrindo a entrevista de inicialização no Codex...'
exec "$CODEX_COMMAND" "$PROMPT_ENTREVISTA"
```

- [ ] **Passo 4: rodar os testes e confirmar que passam**

Comando: `bash tests/test_bootstrap.sh`

Esperado: `BOOTSTRAP APROVADO`.

- [ ] **Passo 5: confirmar que o caminho antigo não regrediu**

Os quatro casos originais do arquivo de teste continuam presentes e passando: Claude
ausente retorna 2, Superpowers ausente é instalado, Superpowers presente não é
reinstalado, marketplace ausente é registrado.

- [ ] **Passo 6: commit** — requer autorização explícita.

```bash
git add iniciar.sh tests/test_bootstrap.sh
git commit -m "Faz o bootstrap bash reconhecer Claude Code e Codex"
```

**Evidência a registrar:** saída completa de `bash tests/test_bootstrap.sh`.

---

## Tarefa 5 — Bootstrap PowerShell com dois hosts

**Objetivo:** a mesma lógica da Tarefa 4 no Windows, com teste próprio — hoje inexistente.

**Arquivos:**
- Modificar: `iniciar.ps1` (reescrita, com BOM UTF-8)
- Criar: `tests/test_bootstrap.ps1` (com BOM UTF-8)

**Interfaces consumidas:** o contrato de saída da Tarefa 4. Os mesmos cinco casos.

- [ ] **Passo 1: escrever o teste que falha**

Criar `tests/test_bootstrap.ps1`, em PowerShell puro, sem Pester:

```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("bootstrap-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TempDir | Out-Null

$falhas = 0

function Assert-Igual($esperado, $obtido, $mensagem) {
    if ($esperado -ne $obtido) {
        Write-Host "FALHA: $mensagem (esperado '$esperado', obtido '$obtido')"
        $script:falhas++
    }
}

function Assert-Contem($caminho, $texto, $mensagem) {
    $conteudo = if (Test-Path $caminho) { Get-Content $caminho -Raw } else { '' }
    if ($conteudo -notmatch [regex]::Escape($texto)) {
        Write-Host "FALHA: $mensagem (nao encontrou '$texto')"
        $script:falhas++
    }
}

function Assert-NaoContem($caminho, $texto, $mensagem) {
    $conteudo = if (Test-Path $caminho) { Get-Content $caminho -Raw } else { '' }
    if ($conteudo -match [regex]::Escape($texto)) {
        Write-Host "FALHA: $mensagem (encontrou '$texto')"
        $script:falhas++
    }
}

function New-HostFalso($nome, $instalado) {
    $caminho = Join-Path $TempDir "$nome.cmd"
    $corpo = @"
@echo off
echo %* >> "%AGENTIC_TEST_LOG%"
if "%1"=="plugin" if "%2"=="list" (
  if "$instalado"=="sim" echo superpowers
)
exit /b 0
"@
    Set-Content -Path $caminho -Value $corpo -Encoding ascii
    return $caminho
}

$log = Join-Path $TempDir 'chamadas.log'
$claudeFalso = New-HostFalso 'claude-falso' 'nao'
$codexFalso = New-HostFalso 'codex-falso' 'nao'
$env:AGENTIC_TEST_LOG = $log

# Caso 1: nenhum host disponivel retorna 2 e cita os dois.
Set-Content -Path $log -Value '' -Encoding utf8
$env:AGENTIC_CLAUDE_BIN = 'comando-claude-inexistente'
$env:AGENTIC_CODEX_BIN = 'comando-codex-inexistente'
$saida = Join-Path $TempDir 'sem-host.log'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RootDir 'iniciar.ps1') *> $saida
Assert-Igual 2 $LASTEXITCODE 'sem host deveria retornar 2'
Assert-Contem $saida 'Claude' 'mensagem deveria citar o Claude Code'
Assert-Contem $saida 'Codex' 'mensagem deveria citar o Codex'

# Caso 2: so o Claude presente instala o Superpowers e abre a entrevista.
Set-Content -Path $log -Value '' -Encoding utf8
$env:AGENTIC_CLAUDE_BIN = $claudeFalso
$env:AGENTIC_CODEX_BIN = 'comando-codex-inexistente'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RootDir 'iniciar.ps1') *> $null
Assert-Igual 0 $LASTEXITCODE 'so claude deveria retornar 0'
Assert-Contem $log 'plugin install superpowers' 'deveria instalar o Superpowers'
Assert-Contem $log 'INICIAR_PROJETO.md' 'deveria abrir a entrevista'

# Caso 3: so o Codex presente usa o Codex.
Set-Content -Path $log -Value '' -Encoding utf8
$env:AGENTIC_CLAUDE_BIN = 'comando-claude-inexistente'
$env:AGENTIC_CODEX_BIN = $codexFalso
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RootDir 'iniciar.ps1') *> $null
Assert-Igual 0 $LASTEXITCODE 'so codex deveria retornar 0'
Assert-Contem $log 'INICIAR_PROJETO.md' 'deveria abrir a entrevista'
Assert-NaoContem $log 'setup-projeto' 'nao deveria acionar o Claude'

# Caso 4: os dois presentes com -Assistente respeita a escolha.
Set-Content -Path $log -Value '' -Encoding utf8
$env:AGENTIC_CLAUDE_BIN = $claudeFalso
$env:AGENTIC_CODEX_BIN = $codexFalso
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RootDir 'iniciar.ps1') -Assistente codex *> $null
Assert-Igual 0 $LASTEXITCODE '-Assistente codex deveria retornar 0'
Assert-NaoContem $log 'setup-projeto' '-Assistente codex nao deveria acionar o Claude'

# Caso 5: Superpowers ja instalado nao reinstala.
Set-Content -Path $log -Value '' -Encoding utf8
$claudeInstalado = New-HostFalso 'claude-instalado' 'sim'
$env:AGENTIC_CLAUDE_BIN = $claudeInstalado
$env:AGENTIC_CODEX_BIN = 'comando-codex-inexistente'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RootDir 'iniciar.ps1') *> $null
Assert-NaoContem $log 'plugin install' 'nao deveria reinstalar o Superpowers'

Remove-Item -Recurse -Force $TempDir
if ($falhas -gt 0) {
    Write-Host "BOOTSTRAP POWERSHELL REPROVADO: $falhas falha(s)"
    exit 1
}
Write-Host 'BOOTSTRAP POWERSHELL APROVADO'
exit 0
```

- [ ] **Passo 2: rodar e confirmar a falha**

Comando: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_bootstrap.ps1`

Falha esperada: o Caso 1 já quebra, porque o `iniciar.ps1` atual não lê
`AGENTIC_CODEX_BIN` e a mensagem não cita o Codex.

- [ ] **Passo 3: reescrever o `iniciar.ps1`**

O arquivo precisa ser salvo com BOM UTF-8. Depois de escrever, confirmar com o Passo 5.

```powershell
[CmdletBinding()]
param(
    [ValidateSet('claude', 'codex')]
    [string]$Assistente
)

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeCommand = if ($env:AGENTIC_CLAUDE_BIN) { $env:AGENTIC_CLAUDE_BIN } else { 'claude' }
$CodexCommand = if ($env:AGENTIC_CODEX_BIN) { $env:AGENTIC_CODEX_BIN } else { 'codex' }
if (-not $Assistente -and $env:AGENTIC_HOST) { $Assistente = $env:AGENTIC_HOST }

$PromptEntrevista = 'Leia prompts/INICIAR_PROJETO.md e conduza a entrevista agora. Siga AGENTS.md. Faça uma pergunta por vez, em português do Brasil. Não crie código do produto.'

function Test-Comando($nome) {
    $encontrado = Get-Command $nome -ErrorAction SilentlyContinue
    return ($null -ne $encontrado)
}

function Show-InstrucoesDeInstalacao {
    Write-Host 'Nenhum host de agente foi encontrado. Nenhuma alteração foi realizada.'
    Write-Host ''
    Write-Host 'Claude Code:'
    Write-Host '  PowerShell: irm https://claude.ai/install.ps1 | iex'
    Write-Host '  WinGet: winget install Anthropic.ClaudeCode'
    Write-Host '  Documentação: https://code.claude.com/docs/en/setup'
    Write-Host ''
    Write-Host 'Codex:'
    Write-Host '  npm: npm install -g @openai/codex'
    Write-Host '  Documentação: https://developers.openai.com/codex/cli'
    Write-Host ''
    Write-Host 'Depois de instalar e autenticar, execute novamente: .\iniciar.ps1'
}

function Resolve-HostDeAgente {
    $temClaude = Test-Comando $ClaudeCommand
    $temCodex = Test-Comando $CodexCommand

    if ($Assistente) {
        if ($Assistente -eq 'claude' -and -not $temClaude) {
            Write-Host "Host 'claude' foi pedido, mas o comando '$ClaudeCommand' não existe. Nada alterado."
            exit 2
        }
        if ($Assistente -eq 'codex' -and -not $temCodex) {
            Write-Host "Host 'codex' foi pedido, mas o comando '$CodexCommand' não existe. Nada alterado."
            exit 2
        }
        return $Assistente
    }

    if ($temClaude -and -not $temCodex) { return 'claude' }
    if ($temCodex -and -not $temClaude) { return 'codex' }
    if (-not $temClaude -and -not $temCodex) {
        Show-InstrucoesDeInstalacao
        exit 2
    }

    if ([System.Console]::IsInputRedirected) {
        Write-Host 'Claude Code e Codex estão instalados e não há terminal para perguntar.'
        Write-Host 'Escolha com -Assistente claude ou -Assistente codex. Nada alterado.'
        exit 2
    }

    Write-Host 'Os dois hosts estão instalados:'
    Write-Host '  [1] Claude Code'
    Write-Host '  [2] Codex'
    $escolha = Read-Host 'Qual você quer usar? [1/2]'
    if ($escolha -eq '1') { return 'claude' }
    if ($escolha -eq '2') { return 'codex' }
    Write-Host 'Escolha inválida. Nada alterado.'
    exit 2
}

function Install-SuperpowersClaude {
    Write-Host 'Verificando o plugin Superpowers no Claude Code...'
    $marketplaces = (& $ClaudeCommand plugin marketplace list 2>$null | Out-String)
    if ($marketplaces -notmatch '(?i)claude-plugins-official') {
        Write-Host 'Registrando o marketplace oficial de plugins...'
        & $ClaudeCommand plugin marketplace add anthropics/claude-plugins-official *> $null
    }
    $plugins = (& $ClaudeCommand plugin list 2>$null | Out-String)
    if ($plugins -match '(?i)superpowers') {
        Write-Host 'Superpowers já está instalado.'
        return
    }
    & $ClaudeCommand plugin install superpowers@claude-plugins-official --scope user
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Não foi possível instalar o Superpowers. Execute claude doctor e tente novamente.'
        exit 3
    }
}

function Install-SuperpowersCodex {
    Write-Host 'Verificando o plugin Superpowers no Codex...'
    $marketplaces = (& $CodexCommand plugin marketplace list 2>$null | Out-String)
    if ($marketplaces -notmatch '(?i)openai') {
        Write-Host 'Registrando o marketplace oficial de plugins...'
        & $CodexCommand plugin marketplace add openai/plugins *> $null
    }
    $plugins = (& $CodexCommand plugin list 2>$null | Out-String)
    if ($plugins -match '(?i)superpowers') {
        Write-Host 'Superpowers já está instalado.'
        return
    }
    & $CodexCommand plugin add superpowers
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Não foi possível instalar o Superpowers. A entrevista não será iniciada.'
        Write-Host 'Instale manualmente e tente de novo:'
        Write-Host '  codex plugin marketplace add openai/plugins'
        Write-Host '  codex plugin add superpowers'
        Write-Host 'Confira os subcomandos disponíveis com: codex plugin --help'
        exit 3
    }
}

function Enable-MultiAgent {
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    $config = Join-Path $codexHome 'config.toml'
    $conteudo = if (Test-Path $config) { Get-Content $config -Raw } else { '' }
    if ($conteudo -match 'multi_agent\s*=\s*true') { return }

    Write-Host ''
    Write-Host 'O Codex precisa de [features] multi_agent = true para despachar subagentes.'
    Write-Host "Isso altera um arquivo fora do repositório: $config"
    Write-Host ''
    if ([System.Console]::IsInputRedirected) {
        Write-Host 'Sem terminal para confirmar. Seguindo sem alterar; os subagentes ficarão indisponíveis.'
        return
    }
    $resposta = Read-Host 'Posso acrescentar essa configuração? [s/N]'
    if ($resposta -match '^[sS]$') {
        if (-not (Test-Path $codexHome)) { New-Item -ItemType Directory -Path $codexHome | Out-Null }
        Add-Content -Path $config -Value "`n[features]`nmulti_agent = true" -Encoding utf8
        Write-Host "Configuração acrescentada em $config"
    } else {
        Write-Host 'Nada alterado. Os subagentes ficarão indisponíveis nesta sessão.'
    }
}

Set-Location $RootDir
$hostEscolhido = Resolve-HostDeAgente

if ($hostEscolhido -eq 'claude') {
    Install-SuperpowersClaude
    Write-Host 'Abrindo a entrevista de inicialização no Claude Code...'
    & $ClaudeCommand --name setup-projeto $PromptEntrevista
    exit $LASTEXITCODE
}

Install-SuperpowersCodex
Enable-MultiAgent
Write-Host 'Abrindo a entrevista de inicialização no Codex...'
& $CodexCommand $PromptEntrevista
exit $LASTEXITCODE
```

- [ ] **Passo 4: rodar os testes e confirmar que passam**

Comando: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_bootstrap.ps1`

Esperado: `BOOTSTRAP POWERSHELL APROVADO`.

- [ ] **Passo 5: confirmar o BOM dos dois arquivos**

```bash
head -c 3 iniciar.ps1 | od -An -tx1
head -c 3 tests/test_bootstrap.ps1 | od -An -tx1
```

Esperado nos dois: `ef bb bf`. Se faltar, regravar com
`Set-Content -Encoding utf8` no PowerShell 5.1, que grava com BOM.

- [ ] **Passo 6: commit** — requer autorização explícita.

```bash
git add iniciar.ps1 tests/test_bootstrap.ps1
git commit -m "Faz o bootstrap PowerShell reconhecer os dois hosts e cria seu teste"
```

**Evidência a registrar:** saída do teste PowerShell e os dois `od` mostrando `ef bb bf`.

---

## Tarefa 6 — Documentação e decisão registrada

**Objetivo:** deixar a documentação coerente com o comportamento novo e registrar por que
o lado Codex não fixa nome de modelo.

**Arquivos:**
- Modificar: `README.md`
- Modificar: `.agents/README.md`
- Modificar: `.agents/PLUGIN_CATALOG.md`
- Modificar: `docs/engineering/TOOLING.md`
- Criar: `docs/engineering/decisions/0001-paridade-entre-hosts.md`

- [ ] **Passo 1: atualizar o README**

Quatro trechos mudam.

Abertura, primeiro parágrafo: trocar "A inicialização instala o plugin Superpowers no
Claude Code" por "A inicialização detecta o host de agente instalado — Claude Code ou
Codex —, instala nele o plugin Superpowers".

Seção `## Iniciar`, acrescentar antes dos blocos de comando:

```markdown
O mesmo comando serve para os dois hosts suportados. Se os dois estiverem instalados, o
bootstrap pergunta qual usar. Para escolher sem interação, use `--host claude` ou
`--host codex` no bash, e `-Assistente claude` ou `-Assistente codex` no PowerShell.
```

Seção `## O que o bootstrap faz`, substituir a lista por:

```markdown
1. Resolve o host: flag explícita, variável `AGENTIC_HOST` ou detecção dos binários.
2. Garante que o Superpowers esteja instalado pelo marketplace oficial do host escolhido.
3. No Codex, confere `[features] multi_agent = true` e pede confirmação antes de alterar
   a configuração do usuário.
4. Abre a entrevista de `prompts/INICIAR_PROJETO.md` em português do Brasil.
```

Seção `## Estrutura principal`, acrescentar ao bloco, depois de `├── .claude/agents/`:

```text
├── .codex/agents/
```

e depois de `├── .agents/`, na lista interna, acrescentar `│   ├── roles.json`.

Seção `## Verificar o template`, substituir o parágrafo final por:

```markdown
Essa validação confirma os arquivos obrigatórios, os gates da inicialização, a simetria
entre os hosts suportados e a ausência de amarras a um host específico no conteúdo de
`.agents/`. Para conferir só a sincronia dos subagentes gerados:

```bash
python scripts/gerar_agentes.py --check
```
```

Seção `## Fontes oficiais`, acrescentar:

```markdown
- [Codex CLI](https://developers.openai.com/codex/cli)
- [Codex — subagentes](https://developers.openai.com/codex/subagents)
- [Codex — plugins](https://developers.openai.com/codex/plugins)
```

- [ ] **Passo 2: atualizar o `.agents/README.md`**

Trocar o último parágrafo por:

```markdown
As integrações específicas de cada host ficam em `.claude/` e `.codex/`, e são geradas a
partir de `roles.json` por `scripts/gerar_agentes.py`. Nenhum desses diretórios contém
regra de projeto: quem adota um host novo aponta para estes arquivos em vez de duplicá-los.
```

Acrescentar `roles.json` à lista de arquivos, no topo:

```markdown
- `roles.json`: fonte única dos papéis, gerada para cada host suportado.
```

- [ ] **Passo 3: atualizar o `.agents/PLUGIN_CATALOG.md`**

Na tabela, trocar a política do Superpowers para "Obrigatório; instalado pelo bootstrap no
host em uso". Em `## Regras de instalação`, trocar o último item por:

```markdown
- Usar subagentes e roteamento de modelo para economizar contexto. Os papéis vêm de
  `.agents/roles.json` e valem para qualquer host suportado.
```

- [ ] **Passo 4: atualizar o `docs/engineering/TOOLING.md`**

Trocar a primeira frase por:

```markdown
O Superpowers é a única instalação automática, feita no host de agente escolhido no
bootstrap. Outras ferramentas serão classificadas durante a entrevista.
```

- [ ] **Passo 5: escrever a ADR**

Criar `docs/engineering/decisions/0001-paridade-entre-hosts.md`:

```markdown
# ADR: paridade entre hosts de agente

- Data: 2026-09-02
- Status: aprovada

## Contexto

O template nasceu amarrado a um host. As regras de processo já eram neutras, porque
ficavam em `AGENTS.md`, mas o bootstrap, a instalação do Superpowers e os subagentes só
existiam para o Claude Code. O Codex passou a oferecer subagentes nativos, plugins e o
próprio Superpowers, tornando a paridade viável sem duplicar regra.

## Decisão

1. Os papéis passam a ter fonte única em `.agents/roles.json`, e `scripts/gerar_agentes.py`
   deriva `.claude/agents/*.md` e `.codex/agents/*.toml`.
2. O lado Codex não fixa nome de modelo. A intenção de custo é expressa por
   `model_reasoning_effort`, `low` para papéis econômicos e `medium` para os demais.
3. O bootstrap resolve o host por flag, variável de ambiente ou detecção, e pergunta
   apenas no empate.
4. O validador deixa de proibir a citação de um fornecedor e passa a exigir simetria.

## Alternativas consideradas

- Manter os dois conjuntos de subagentes à mão: rejeitada por divergência silenciosa.
- Não criar subagentes no Codex: rejeitada por perder isolamento de contexto e roteamento
  de modelo econômico.
- Scripts de bootstrap separados por host: rejeitada por duplicar lógica.

## Consequências

- Adicionar ou alterar um papel passa a ser uma edição em um arquivo só.
- Arquivos em `.claude/agents/` e `.codex/agents/` não devem ser editados à mão.
- O Codex expressa permissão por `sandbox_mode`, sem lista de ferramentas. A distinção
  entre escrever arquivo e executar comando fica apenas na instrução do papel.
- Nomes de modelo do Claude continuam fixados; os da OpenAI, não. É uma assimetria
  deliberada.

## Condições para revisão futura

- O Codex passar a aceitar lista de ferramentas por subagente.
- Um terceiro host entrar no escopo.
- O marketplace ou os subcomandos de plugin de qualquer um dos hosts mudarem de forma.
```

- [ ] **Passo 6: rodar o validador**

Comando: `python scripts/validate_template.py`

Esperado: `VALIDAÇÃO APROVADA`.

- [ ] **Passo 7: commit** — requer autorização explícita.

```bash
git add README.md .agents/README.md .agents/PLUGIN_CATALOG.md docs/engineering
git commit -m "Documenta paridade entre hosts e registra a decisao"
```

**Evidência a registrar:** saída de `validate_template.py` aprovando.

---

## Checkpoints

- Após a Tarefa 1: revisão de conformidade com a SPEC — os 8 papéis gerados preservam
  `tools` e `model` idênticos aos atuais no Claude.
- Após a Tarefa 3: revisão de qualidade — nenhuma regra de processo restou só no
  `CLAUDE.md`.
- Após a Tarefa 5: revisão de segurança — a única escrita fora do repositório é
  `~/.codex/config.toml`, sempre precedida de confirmação, e nenhum log registra
  credencial.
- Após a Tarefa 6: revisão final de diff contra a SPEC, critério por critério.

## Regressão final

- Testes focados: `python -m unittest discover -s tests -p "test_*.py"`
- Suíte de bootstrap: `bash tests/test_bootstrap.sh` e
  `powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_bootstrap.ps1`
- Estrutura: `python scripts/validate_template.py`
- Sincronia: `python scripts/gerar_agentes.py --check`
- BOM: `head -c 3 iniciar.ps1 | od -An -tx1` e o mesmo em `tests/test_bootstrap.ps1`
- Verificação do diff: `git diff --stat` contra CA1 a CA11 da SPEC.
- Validação humana pendente e obrigatória: executar `./iniciar.sh` em máquina com Codex
  instalado e confirmar instalação do Superpowers, aviso de `multi_agent` e abertura da
  entrevista. Até lá, o suporte a Codex está verificado apenas por binário falso.

## Aprovação

- Aprovador:
- Evidência da aprovação:
