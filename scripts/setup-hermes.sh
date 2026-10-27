#!/usr/bin/env bash
# Configure Hermes for this project: local terminal backend + workspace scope,
# then hand off to Hermes' official interactive setup flows.
# Run only on the target Mac, after scripts/install-hermes.sh.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ Refusing: this host is $(uname -s), not macOS." >&2
  exit 1
fi

export PATH="$HOME/.local/bin:$PATH"
if ! command -v hermes >/dev/null 2>&1; then
  echo "❌ hermes not found on PATH. Run scripts/install-hermes.sh --install first." >&2
  exit 1
fi

WORKSPACE="${HERMES_WORKSPACE:-$HOME/Developer}"
if [[ ! -d "$WORKSPACE" ]]; then
  read -r -p "Workspace '$WORKSPACE' does not exist. Create it now? [y/N] " ANS
  [[ "$ANS" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
  mkdir -p "$WORKSPACE"
fi

echo "==> Applying Phase 2 configuration (non-secret settings to config.yaml)..."
hermes config set terminal.backend local
hermes config set terminal.cwd "$WORKSPACE"
hermes config set display.tool_progress all

echo "==> Reviewing current toolsets..."
hermes tools || true

echo
echo "=== Manual steps you must complete interactively ==="
cat <<'EOF'
1. Provider + auth (Phase 2.2–2.3):        hermes model
2. Enable toolsets (Phase 2.5–2.8):        hermes tools
   - terminal + file (required)
   - browser (if you configured browser access)
   - computer_use (installs cua-driver if missing)
   - memory, skills, todo as needed
3. SOUL.md identity (Phase 2.9):           cp SOUL.md ~/.hermes/SOUL.md   (edit first!)
4. First chat (Phase 2.10–2.11):           hermes
   Ask it to run `uname -a` and to create a scratch file in the workspace.
5. Telegram (Phase 3):                      hermes gateway setup
   - Create the bot with @BotFather, keep the token only in ~/.hermes/.env
   - Set TELEGRAM_ALLOWED_USERS to YOUR numeric Telegram user id (never empty)
EOF
echo
echo "After those steps, run scripts/verify-hermes.sh to check your work."