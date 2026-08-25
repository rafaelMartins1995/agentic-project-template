#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_COMMAND="${AGENTIC_CLAUDE_BIN:-claude}"

show_install_help() {
  printf '%s\n' \
    'Claude Code não foi encontrado. Nenhuma alteração foi realizada.' \
    '' \
    'Instalação oficial:' \
    '  macOS/Linux: curl -fsSL https://claude.ai/install.sh | bash' \
    '  macOS/Homebrew: brew install --cask claude-code' \
    '' \
    'Documentação: https://code.claude.com/docs/en/setup' \
    '' \
    'Depois de instalar e autenticar, execute novamente: ./iniciar.sh'
}

if ! command -v "$CLAUDE_COMMAND" >/dev/null 2>&1; then
  show_install_help
  exit 2
fi

cd "$ROOT_DIR"

printf '%s\n' 'Verificando o plugin Superpowers...'
if "$CLAUDE_COMMAND" plugin list 2>/dev/null | grep -qi 'superpowers'; then
  printf '%s\n' 'Superpowers já está instalado.'
else
  if ! "$CLAUDE_COMMAND" plugin install superpowers@claude-plugins-official --scope user; then
    printf '%s\n' \
      'Não foi possível instalar o Superpowers. A entrevista não será iniciada.' \
      'Verifique sua conexão e autenticação com: claude doctor' >&2
    exit 3
  fi
fi

printf '%s\n' 'Abrindo a entrevista de inicialização...'
exec "$CLAUDE_COMMAND" --name setup-projeto "Leia prompts/INICIAR_PROJETO.md e conduza a entrevista agora. Siga AGENTS.md. Faça uma pergunta por vez, em português do Brasil. Não crie código do produto."
