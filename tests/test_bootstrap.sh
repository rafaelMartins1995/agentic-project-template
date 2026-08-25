#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

set +e
AGENTIC_CLAUDE_BIN="comando-claude-inexistente" "$ROOT_DIR/iniciar.sh" >"$TEMP_DIR/missing.log" 2>&1
missing_status=$?
set -e

if [ "$missing_status" -ne 2 ]; then
  printf '%s\n' "Falha: ausência do Claude deveria retornar 2, retornou $missing_status" >&2
  exit 1
fi

if ! grep -q 'Nenhuma alteração foi realizada' "$TEMP_DIR/missing.log"; then
  printf '%s\n' 'Falha: mensagem de interrupção segura não encontrada.' >&2
  exit 1
fi

FAKE_CLAUDE="$TEMP_DIR/fake-claude"
CALL_LOG="$TEMP_DIR/calls.log"
cat >"$FAKE_CLAUDE" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${AGENTIC_TEST_LOG:?}"
if [ "${1:-}" = "plugin" ] && [ "${2:-}" = "list" ]; then
  exit 0
fi
exit 0
FAKE
chmod +x "$FAKE_CLAUDE"

AGENTIC_CLAUDE_BIN="$FAKE_CLAUDE" AGENTIC_TEST_LOG="$CALL_LOG" "$ROOT_DIR/iniciar.sh" >/dev/null

grep -q 'plugin install superpowers@claude-plugins-official --scope user' "$CALL_LOG"
grep -q -- '--name setup-projeto' "$CALL_LOG"
grep -q 'prompts/INICIAR_PROJETO.md' "$CALL_LOG"

: >"$CALL_LOG"
cat >"$FAKE_CLAUDE" <<'FAKE_INSTALLED'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${AGENTIC_TEST_LOG:?}"
if [ "${1:-}" = "plugin" ] && [ "${2:-}" = "list" ]; then
  printf '%s\n' 'superpowers@claude-plugins-official'
fi
exit 0
FAKE_INSTALLED
chmod +x "$FAKE_CLAUDE"

AGENTIC_CLAUDE_BIN="$FAKE_CLAUDE" AGENTIC_TEST_LOG="$CALL_LOG" "$ROOT_DIR/iniciar.sh" >/dev/null

if grep -q 'plugin install' "$CALL_LOG"; then
  printf '%s\n' 'Falha: Superpowers já instalado não deve ser reinstalado.' >&2
  exit 1
fi
grep -q -- '--name setup-projeto' "$CALL_LOG"

FAKE_NO_MARKETPLACE="$TEMP_DIR/fake-claude-no-marketplace"
MARKETPLACE_STATE="$TEMP_DIR/marketplace-state"
: >"$MARKETPLACE_STATE"
cat >"$FAKE_NO_MARKETPLACE" <<'FAKE_NOMKT'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${AGENTIC_TEST_LOG:?}"
STATE_FILE="${AGENTIC_TEST_STATE:?}"
if [ "${1:-}" = "plugin" ] && [ "${2:-}" = "marketplace" ] && [ "${3:-}" = "add" ]; then
  printf '%s\n' 'claude-plugins-official' > "$STATE_FILE"
  exit 0
fi
if [ "${1:-}" = "plugin" ] && [ "${2:-}" = "marketplace" ] && [ "${3:-}" = "list" ]; then
  [ -s "$STATE_FILE" ] && cat "$STATE_FILE"
  exit 0
fi
if [ "${1:-}" = "plugin" ] && [ "${2:-}" = "list" ]; then
  exit 0
fi
if [ "${1:-}" = "plugin" ] && [ "${2:-}" = "install" ]; then
  if [ -s "$STATE_FILE" ]; then
    exit 0
  fi
  printf '%s\n' 'Marketplace "claude-plugins-official" not found' >&2
  exit 1
fi
exit 0
FAKE_NOMKT
chmod +x "$FAKE_NO_MARKETPLACE"

: >"$CALL_LOG"
set +e
AGENTIC_CLAUDE_BIN="$FAKE_NO_MARKETPLACE" AGENTIC_TEST_LOG="$CALL_LOG" AGENTIC_TEST_STATE="$MARKETPLACE_STATE" "$ROOT_DIR/iniciar.sh" >"$TEMP_DIR/no-marketplace.log" 2>&1
no_marketplace_status=$?
set -e

if [ "$no_marketplace_status" -ne 0 ]; then
  printf '%s\n' "Falha: bootstrap deveria registrar o marketplace ausente e seguir, retornou $no_marketplace_status" >&2
  cat "$TEMP_DIR/no-marketplace.log" >&2
  exit 1
fi

grep -q 'plugin marketplace add anthropics/claude-plugins-official' "$CALL_LOG"
grep -q 'plugin install superpowers@claude-plugins-official --scope user' "$CALL_LOG"
grep -q -- '--name setup-projeto' "$CALL_LOG"

printf '%s\n' 'BOOTSTRAP APROVADO'
