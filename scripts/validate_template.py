#!/usr/bin/env python3
"""Validação estrutural do template; usa apenas a biblioteca padrão."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

REQUIRED = [
    "README.md",
    "docs/USAR_COMO_TEMPLATE.md",
    "AGENTS.md",
    "CLAUDE.md",
    ".agents/PROTOCOL.md",
    ".agents/ROUTING.md",
    ".agents/PLUGIN_CATALOG.md",
    ".agents/presets/backend-fastapi.md",
    ".agents/presets/frontend-react.md",
    ".claude/agents/explorer.md",
    ".claude/agents/frontend-engineer.md",
    ".claude/agents/backend-engineer.md",
    ".claude/agents/test-engineer.md",
    ".claude/agents/code-reviewer.md",
    ".claude/agents/security-reviewer.md",
    ".claude/agents/documenter.md",
    "prompts/INICIAR_PROJETO.md",
    "prompts/INICIAR_TAREFA.md",
    "docs/engineering/PROJECT_PROFILE.md",
    "docs/engineering/AGENT_CATALOG.md",
    "docs/engineering/TOOLING.md",
    "docs/engineering/EXECUTION_CHECKLIST.md",
    "docs/engineering/templates/SPEC_TEMPLATE.md",
    "docs/engineering/templates/PLAN_TEMPLATE.md",
    "iniciar.sh",
    "iniciar.ps1",
    "iniciar.cmd",
]

REQUIRED_AGENT_FIELDS = ("name", "description", "tools", "model")


def validate_required_files(errors: list[str]) -> None:
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            errors.append(f"Arquivo obrigatório ausente: {relative}")


def validate_agents(errors: list[str]) -> None:
    for path in sorted((ROOT / ".claude" / "agents").glob("*.md")):
        text = path.read_text(encoding="utf-8")
        match = re.match(r"^---\n(.*?)\n---\n", text, flags=re.DOTALL)
        if not match:
            errors.append(f"Frontmatter ausente: {path.relative_to(ROOT)}")
            continue
        frontmatter = match.group(1)
        for field in REQUIRED_AGENT_FIELDS:
            if not re.search(rf"^{field}:\s*\S", frontmatter, flags=re.MULTILINE):
                errors.append(f"Campo '{field}' ausente: {path.relative_to(ROOT)}")


def validate_gates(errors: list[str]) -> None:
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    prompt = (ROOT / "prompts" / "INICIAR_PROJETO.md").read_text(encoding="utf-8")
    for term in ("SPEC completa", "plano completo", "Não criar código do produto"):
        combined = f"{agents}\n{prompt}".casefold()
        if term.casefold() not in combined:
            errors.append(f"Gate obrigatório não encontrado: {term}")


def validate_vendor_neutrality(errors: list[str]) -> None:
    forbidden = "co" + "dex"
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".md", ".sh", ".ps1", ".cmd", ".py"}:
            continue
        if path == Path(__file__):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if forbidden.casefold() in text.casefold():
            errors.append(f"Referência específica proibida em: {path.relative_to(ROOT)}")


def main() -> int:
    errors: list[str] = []
    validate_required_files(errors)
    validate_agents(errors)
    validate_gates(errors)
    validate_vendor_neutrality(errors)

    if errors:
        print("VALIDAÇÃO FALHOU")
        for error in errors:
            print(f"- {error}")
        return 1

    print("VALIDAÇÃO APROVADA")
    print(f"Arquivos obrigatórios: {len(REQUIRED)}")
    print("Presets: backend-fastapi, frontend-react")
    print("Gate: SPEC e plano completos antes de código")
    return 0


if __name__ == "__main__":
    sys.exit(main())
