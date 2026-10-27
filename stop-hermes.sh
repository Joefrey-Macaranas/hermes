#!/usr/bin/env bash
# Emergency stop: halt all new Hermes work, then report gateway status.
# Usage: bash stop-hermes.sh        (resume later with: hermes resume)
export PATH="$HOME/.local/bin:$PATH"; command -v hermes >/dev/null 2>&1 || { echo "❌ hermes not found on PATH — run this on the target Mac." >&2; exit 1; }; hermes pause && echo "🛑 Hermes paused — no new cron, kanban, gateway, CLI, TUI or Desktop turns will start. Resume with: hermes resume"; echo; echo "=== Gateway status ==="; hermes gateway status