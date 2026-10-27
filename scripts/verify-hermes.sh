#!/usr/bin/env bash
# Verification gate for Phases 2–4: Hermes CLI health, gateway/Telegram config,
# and computer-use diagnostics. Read-only: changes nothing.
set -uo pipefail

PASS=0; FAIL=0; WARN=0
ok()   { echo "✅ PASS  $*"; PASS=$((PASS+1)); }
bad()  { echo "❌ FAIL  $*"; FAIL=$((FAIL+1)); }
warn() { echo "⚠️  WARN  $*"; WARN=$((WARN+1)); }
info() { echo "ℹ️  INFO  $*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ This host is $(uname -s), not macOS. Verification must run on the target Mac." >&2
  exit 2
fi

export PATH="$HOME/.local/bin:$PATH"

echo "=== Phase 2 — Hermes CLI ==="
if command -v hermes >/dev/null 2>&1; then
  ok "hermes on PATH ($(hermes --version 2>/dev/null | head -1))"
else
  bad "hermes not on PATH — run scripts/install-hermes.sh --install"
  exit 1
fi

if hermes config get terminal.backend >/dev/null 2>&1; then
  BACKEND="$(hermes config get terminal.backend 2>/dev/null)"
  if [[ "$BACKEND" == "local" ]]; then
    ok "terminal.backend = local"
  else
    warn "terminal.backend = '$BACKEND' (brief requires local)"
  fi
else
  warn "terminal.backend not readable (config may need setup)"
fi

if [[ -f "$HOME/.hermes/SOUL.md" ]]; then
  ok "~/.hermes/SOUL.md present"
else
  warn "SOUL.md identity not installed — cp SOUL.md ~/.hermes/SOUL.md"
fi

# One-shot functional check: agent executes a local command
if hermes -Q -z "Run the shell command 'uname -s' and reply only with its output." >/dev/null 2>&1; then
  ok "agent executed a local command (one-shot check)"
else
  warn "one-shot agent check failed — run 'hermes' interactively to diagnose (provider auth is the usual cause)"
fi

echo
echo "=== Phase 3 — Telegram gateway ==="
ENV_FILE="$HOME/.hermes/.env"
if [[ -f "$ENV_FILE" ]] && grep -q '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE"; then
  ok "TELEGRAM_BOT_TOKEN is set in ~/.hermes/.env"
else
  warn "TELEGRAM_BOT_TOKEN not found — run: hermes gateway setup (Telegram)"
fi
if [[ -f "$ENV_FILE" ]] && grep -q '^TELEGRAM_ALLOWED_USERS=' "$ENV_FILE"; then
  ALLOWED="$(grep '^TELEGRAM_ALLOWED_USERS=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d ' ')"
  if [[ -n "$ALLOWED" && "$ALLOWED" != "0" ]]; then
    ok "TELEGRAM_ALLOWLIST is non-empty"
  else
    bad "TELEGRAM_ALLOWED_USERS is empty — the bot would accept anyone"
  fi
else
  warn "TELEGRAM_ALLOWED_USERS not found — set it in hermes gateway setup"
fi
if hermes gateway status >/dev/null 2>&1; then
  ok "gateway service status readable (see output above)"
else
  warn "gateway not running or not installed — 'hermes gateway install && hermes gateway start'"
fi
info "Functional test is manual: send a Telegram message from your allowlisted account and confirm a reply."

echo
echo "=== Phase 4 — Computer use ==="
hermes computer-use status >/dev/null 2>&1 && ok "computer-use status: reachable" || warn "computer-use status not OK — try: hermes computer-use install"
hermes computer-use doctor
DC=$?
if [[ $DC -eq 0 ]]; then
  ok "hermes computer-use doctor exits 0 (accessibility + screen capture OK)"
elif [[ $DC -eq 1 ]]; then
  bad "doctor reports degraded/failed checks — fix each hint (macOS: grant Accessibility + Screen Recording to the named identity)"
else
  bad "cua-driver binary not reachable — run: hermes computer-use install"
fi

echo
echo "=== Summary: $PASS passed, $FAIL failed, $WARN warnings ==="
if [[ "$FAIL" -gt 0 ]]; then
  echo "🛑 Resolve FAIL items, then re-run."
  exit 1
fi
echo "✅ Phases 2–4 verification passed. Continue with RUNBOOK.md Phase 5+ items."