#!/usr/bin/env bash
# =============================================================================
# start-here.sh — single guided entrypoint for the Hermes Autonomous Developer
#
# Runs the Phase 1 preflight, then walks every RUNBOOK.md phase in order,
# prompting you at each step. Progress is saved so you can quit and resume.
#
#   Usage:  bash start-here.sh
#
# - Run this ON the target Apple Silicon Mac, in a real terminal, logged in.
# - Read-only apart from: Brewfile installs, the gated Hermes installer,
#   config writes through official Hermes commands, and this script's own
#   progress file (.setup-progress).
# - Never prints or stores secrets; credentials stay in ~/.hermes/.env.
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$ROOT/.setup-progress"
SCRIPTS="$ROOT/scripts"

# ---------------------------------------------------------------- helpers ----
ok()    { printf '  ✅ %s\n' "$*"; }
bad()   { printf '  ❌ %s\n' "$*"; }
warn()  { printf '  ⚠️  %s\n' "$*"; }
info()  { printf '  ℹ️  %s\n' "$*"; }

ask() {  # ask "question" -> 0 on yes
  local reply
  read -r -p "  ❓ $1 [y/N] " reply
  [[ "$reply" =~ ^[Yy] ]]
}
hold() { read -r -p "  ⏎ $1 — press Enter when done... "; }

banner() {
  echo
  echo "============================================================================="
  echo "  $1"
  echo "============================================================================="
}

phase_done()    { grep -qx "phase=$1" "$STATE" 2>/dev/null; }
phase_pending() { grep -qx "pending=$1" "$STATE" 2>/dev/null; }
mark_done()     { grep -qx "phase=$1" "$STATE" 2>/dev/null || echo "phase=$1" >> "$STATE"; }
mark_pending()  { grep -qx "pending=$1" "$STATE" 2>/dev/null || echo "pending=$1" >> "$STATE"; }
clear_pending() { [[ -f "$STATE" ]] && sed -i.bak "/^pending=$1\$/d" "$STATE" && rm -f "$STATE.bak"; }

RESULTS=()   # "N|status|label" for the final summary

# Safety net: while an emergency-stop test is in progress, remind on ANY exit
# path (including quit/retry) that Hermes may still be paused.
PAUSED=0
trap 'if [[ "$PAUSED" == "1" ]]; then echo; warn "Hermes may still be PAUSED — run: hermes resume"; fi' EXIT

# close_phase N "label" — prompt for any remaining manual items, record result
close_phase() {
  local n="$1" label="$2" choice
  if ask "All items for Phase $n ($label) complete?"; then
    mark_done "$n"; clear_pending "$n"
    RESULTS+=("$n|DONE|$label")
  else
    warn "Phase $n left with pending items."
    read -r -p "  [c]ontinue to next phase anyway, [r]etry this phase, [q]uit: " choice
    case "$choice" in
      r|R) [[ "$PAUSED" == "1" ]] && warn "Reminder: Hermes may still be PAUSED — run: hermes resume"; return 1 ;;
      q|Q) echo "Progress saved to $STATE. Re-run start-here.sh to resume."; exit 0 ;;
      *)   mark_pending "$n"; RESULTS+=("$n|PENDING|$label") ;;
    esac
  fi
  return 0
}

# ------------------------------------------------------------- guards --------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ Refusing: this host is $(uname -s), not macOS." >&2
  echo "   Run this script on the target Apple Silicon Mac." >&2
  exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "❌ Refusing: architecture is $(uname -m); target is Apple Silicon." >&2
  exit 1
fi
if [[ ! -t 0 ]]; then
  echo "❌ This is an interactive walkthrough — run it in a real terminal." >&2
  exit 1
fi
for f in preflight-macos.sh install-hermes.sh setup-hermes.sh verify-hermes.sh; do
  if [[ ! -f "$SCRIPTS/$f" ]]; then echo "❌ Missing $SCRIPTS/$f" >&2; exit 1; fi
done
export PATH="$HOME/.local/bin:$PATH"
touch "$STATE"

# Normalize a hand-edited state file that lacks a final newline: appending to it
# would merge the new entry onto the last line (e.g. "phase=2" + "pending=1"
# becomes "phase=2pending=1") and silently corrupt the tracker.
if [[ -s "$STATE" ]] && [[ -n "$(tail -c 1 "$STATE")" ]]; then
  echo >> "$STATE"
fi

# Workspace path — initialized here so it exists even when Phase 1 is skipped
# on resume (set -u would otherwise abort later phases referencing it).
WS="${HERMES_WORKSPACE:-$HOME/Developer}"

echo "Hermes Autonomous Developer — guided setup"
echo "Progress file: $STATE (quit anytime with q; re-run to resume)"

# =========================================================================
banner "PHASE 1 — Mac preparation"
# =========================================================================
if ! phase_done 1; then
  if ! bash "$SCRIPTS/preflight-macos.sh"; then
    bad "Preflight failed. Fix every ❌ above, then re-run start-here.sh."
    exit 1
  fi
  ok "Preflight passed."

  if command -v brew >/dev/null 2>&1; then
    if ask "Install/update Brewfile packages (git, gh, python, node, chrome)?"; then
      brew bundle --file "$ROOT/Brewfile" || warn "brew bundle reported issues — review output."
    fi
  else
    warn "Homebrew not installed — optional. See README for the install command."
  fi

  # 1.6 workspace
  info "Workspace will be: $WS"
  if ask "Create/use this workspace directory?"; then
    mkdir -p "$WS" && ok "Workspace ready: $WS"
  else
    read -r -p "  Enter your workspace path (or press Enter to keep $WS): " NEW_WS
    case "${NEW_WS:-}" in
      ""|[Nn]|[Nn][Oo])
        info "Keeping default workspace path (not created yet): $WS" ;;
      *)
        WS="$NEW_WS"
        mkdir -p "$WS" 2>/dev/null && ok "Workspace ready: $WS" || warn "Could not create $WS — create it manually." ;;
    esac
    export HERMES_WORKSPACE="$WS"
  fi

  # 1.7–1.10 reminders (macOS GUI grants happen later, after cua-driver exists)
  cat <<'EOF'
  Manual permission notes (Phase 1.7–1.9):
    • Accessibility & Screen Recording grants are checked in Phase 4 after the
      computer-use driver installs — grant them to the identity that
      `hermes computer-use doctor` names.
    • Automation: approve only when macOS prompts and you recognize the app.
    • Keep the Mac awake and logged into the desktop while the agent runs.
EOF
  hold "confirm you have read the permission notes (1.7–1.10)"
  close_phase 1 "Mac preparation" || exec bash "$0"
fi

# =========================================================================
banner "PHASE 2 — Hermes CLI installation"
# =========================================================================
if ! phase_done 2; then
  phase_pending 2 && info "Resuming Phase 2 (left pending earlier)."

  if ! command -v hermes >/dev/null 2>&1; then
    if ask "Install the official Hermes Agent now (gated installer)?"; then
      bash "$SCRIPTS/install-hermes.sh" --install || { bad "Installer failed — fix and re-run."; exit 1; }
      hash -r 2>/dev/null
    fi
  fi
  if ! command -v hermes >/dev/null 2>&1; then
    warn "Hermes is not installed yet — Phase 2 cannot complete."
    mark_pending 2; RESULTS+=("2|PENDING|Hermes CLI installation")
    echo "Re-run start-here.sh after installing."; exit 1
  fi
  ok "Hermes installed: $(hermes --version 2>/dev/null | head -1)"

  # 2.2–2.3 provider + auth (interactive, user's choice)
  info "Phase 2.2–2.3: choose your AI model provider and authenticate."
  info "Minimum context is 64K tokens. Credentials stay in ~/.hermes/.env."
  if ask "Run 'hermes model' now?"; then
    hermes model || warn "hermes model exited non-zero — re-run it manually."
  else
    hold "complete 'hermes model' yourself, then"
  fi

  # 2.4–2.8 config + tools
  if ask "Apply local-terminal + workspace config (scripts/setup-hermes.sh)?"; then
    bash "$SCRIPTS/setup-hermes.sh" || warn "setup script reported issues."
  fi
  if ask "Configure toolsets now ('hermes tools')? Enable terminal + file, browser, computer_use, memory, skills?"; then
    hermes tools || warn "hermes tools exited non-zero."
  fi

  # 2.9 SOUL.md
  if [[ -f "$ROOT/SOUL.md" ]]; then
    if ask "Install SOUL.md identity to ~/.hermes/SOUL.md (review/edit it first)?"; then
      cp "$ROOT/SOUL.md" "$HOME/.hermes/SOUL.md" && ok "SOUL.md installed." || warn "Could not copy SOUL.md — ensure ~/.hermes exists, then copy manually."
    fi
  fi

  # 2.10–2.11 functional verification
  info "Phase 2.10: verify the agent runs local commands."
  hold "start 'hermes', ask it to run 'uname -a', confirm it replies, then exit the chat"
  info "Phase 2.11: verify file create/edit."
  hold "ask Hermes to create a scratch file in $WS, confirm it exists, then delete it"
  close_phase 2 "Hermes CLI installation" || exec bash "$0"
fi

# =========================================================================
banner "PHASE 3 — Telegram gateway"
# =========================================================================
if ! phase_done 3; then
  cat <<'EOF'
  Manual steps first (do these in Telegram):
    1. Open @BotFather → /newbot → note the token (keep it SECRET).
    2. Message a trusted ID bot → note YOUR numeric user id.
EOF
  if ask "Ready to run 'hermes gateway setup' and enter the token + user id?"; then
    hermes gateway setup || warn "gateway setup exited non-zero."
  else
    hold "complete 'hermes gateway setup' yourself, then"
  fi

  # allowlist hard check — never empty
  ENV_FILE="$HOME/.hermes/.env"
  ALLOWED=""
  [[ -f "$ENV_FILE" ]] && ALLOWED="$(grep '^TELEGRAM_ALLOWED_USERS=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d ' ')"
  if [[ -n "$ALLOWED" && "$ALLOWED" != "0" ]]; then
    ok "Telegram allowlist is non-empty (Phase 3.4/8.5)."
  else
    bad "TELEGRAM_ALLOWED_USERS missing or empty — the bot would accept strangers."
    ask "Fix it now via 'hermes gateway setup'?" && hermes gateway setup
  fi

  info "Phase 3.7–3.10: functional tests over Telegram."
  hold "send a test message from your allowlisted account and confirm a reply (/new works, tool progress shows)"
  hold "ask the bot to send a screenshot — confirm the image arrives as an attachment"
  hold "submit one small remote task from your phone and confirm completion"
  close_phase 3 "Telegram gateway" || exec bash "$0"
fi

# =========================================================================
banner "PHASE 4 — Native computer use"
# =========================================================================
if ! phase_done 4; then
  if ask "Install/repair the computer-use driver now?"; then
    hermes computer-use install || warn "computer-use install reported issues."
  fi
  echo "  Running 'hermes computer-use doctor' (exit 0 = all checks pass):"
  hermes computer-use doctor
  DC=$?
  if [[ $DC -ne 0 ]]; then
    if [[ $DC -eq 2 ]]; then
      bad "Doctor exit=2 — the cua-driver binary is not reachable."
      info "Run 'hermes computer-use install', then re-run this walkthrough."
    else
      bad "Doctor exit=$DC — degraded checks. Grant Accessibility + Screen Recording to the identity it names:"
      info "System Settings → Privacy & Security → Accessibility / Screen Recording"
      info "Then quit/reopen the terminal and re-run this walkthrough."
    fi
    mark_pending 4; RESULTS+=("4|PENDING|Native computer use")
    exit 1
  fi
  ok "Doctor passes (4.2–4.4)."

  info "GUI interaction tests (4.5–4.12):"
  hold "have Hermes use computer_use to click/type in Finder, Chrome, VS Code and Terminal; confirm each action with a fresh screenshot"
  close_phase 4 "Native computer use" || exec bash "$0"
fi

# =========================================================================
banner "PHASE 5 — Visible control (background computer-use path)"
# =========================================================================
if ! phase_done 5; then
  cat <<'EOF'
  Per RUNBOOK.md: Hermes uses the background computer_use path (no cursor warp,
  focus steal, or human-like disguise). Observe agent activity on screen and
  verify STOP works.
EOF
  hold "watch a full GUI task run visibly (overlay/evidence of agent activity)"
  info "STOP test (5.13): pause Hermes, confirm new work halts, then resume."
  if ask "Run the emergency-stop test now ('stop-hermes.sh' = hermes pause + gateway status)?"; then
    bash "$ROOT/stop-hermes.sh" || warn "stop-hermes.sh exited non-zero — the gateway-status part may be unavailable; the pause itself should have run."
    PAUSED=1
    hold "verify new work is halted: no cron/gateway turns starting, Telegram messages wait, CLI/TUI reports paused"
    if ask "Resume now ('hermes resume')?"; then
      if hermes resume; then
        ok "Hermes resumed — new work can start again."
        PAUSED=0
      else
        bad "'hermes resume' reported an error — run it manually and confirm."
      fi
    else
      warn "Leaving Hermes PAUSED — run 'hermes resume' before finishing (this script will remind you on exit)."
    fi
  else
    hold "test STOP manually ('hermes pause' then 'hermes resume') and confirm both work"
  fi
  close_phase 5 "Visible control" || exec bash "$0"
fi

# =========================================================================
banner "PHASE 6 — Software developer capabilities"
# =========================================================================
if ! phase_done 6; then
  info "Skills: run 'hermes skills browse' later; install what your stack needs."
  hold "install the development workflow skills you need (6.1)"
  hold "verify discovery/analysis/plan flow: give Hermes a small feature request and watch it plan (6.2–6.4)"
  hold "verify file edit, package management, git branch+commit, IDE and browser usage (6.5–6.9)"
  hold "verify test + lint + build run, browser QA, and build-error recovery on a real repo (6.10–6.13)"
  info "6.14–6.16 (GitHub PR / deploy / rollback) need credentials and explicit approval:"
  hold "set up gh auth or the GitHub MCP server if you want PR creation (6.14)"
  close_phase 6 "Software developer capabilities" || exec bash "$0"
fi

# =========================================================================
banner "PHASE 7 — Autonomous task execution"
# =========================================================================
if ! phase_done 7; then
  info "End-to-end Telegram development task:"
  hold "submit a real small task via Telegram; watch plan → execution → tests → completion report (7.1–7.10)"
  hold "verify '/stop' cancels a running task (7.11)"
  info "7.12–7.13 (serialize GUI tasks, restore after failure): confirm only one"
  info "computer_use session drives the desktop and Hermes sessions list shows history."
  hold "confirm GUI task serialization and session persistence"
  close_phase 7 "Autonomous task execution" || exec bash "$0"
fi

# =========================================================================
banner "PHASE 8 — Authorization and control"
# =========================================================================
if ! phase_done 8; then
  hold "confirm approvals are NOT disabled (mode manual/smart; no --yolo) (8.1–8.4)"
  hold "test that a non-allowlisted Telegram user is REFUSED (8.5)"
  info "Credential hygiene (8.6): secrets only in ~/.hermes/.env; check file mode:"
  ls -l "$HOME/.hermes/.env" 2>/dev/null | sed 's/^/    /' || true
  hold "confirm env file is private and audit logs exist (hermes logs) (8.6–8.7)"
  hold "confirm emergency disable: 'hermes pause' + 'hermes gateway stop' (8.8)"
  close_phase 8 "Authorization and control" || exec bash "$0"
fi

# =========================================================================
banner "PHASE 9 — Reporting and observability"
# =========================================================================
if ! phase_done 9; then
  info "Confirm tool_progress=all is showing activity in Telegram (9.1–9.2):"
  hermes config get display.tool_progress 2>/dev/null | sed 's/^/    display.tool_progress = /'
  hold "request milestone screenshots and confirm attachments arrive (9.3–9.4)"
  hold "confirm error/retry, commit/PR, and test-result reporting in chat (9.5–9.7)"
  hold "confirm final summary + history via 'hermes sessions list' / 'hermes insights' (9.8–9.9)"
  close_phase 9 "Reporting and observability" || exec bash "$0"
fi

# =========================================================================
banner "PHASE 10 — Production deployment"
# =========================================================================
if ! phase_done 10; then
  if ask "Install the gateway as a launchd user service now?"; then
    hermes gateway install || warn "gateway install reported issues."
  fi
  if ask "Start the service and show status?"; then
    hermes gateway start; hermes gateway status
  fi
  info "Power/sleep (10.4): keep the Mac awake while the agent works, e.g.:"
  info "    sudo pmset -a sleep 0        # reversible: sudo pmset -a sleep 10"
  hold "apply power settings as desired (10.4)"
  info "Reboot test (10.5–10.6): restart the Mac, log in, then confirm:"
  hold "gateway status is running and Telegram answers after reboot"
  hold "run the full battery: Chrome interaction, IDE typing, Terminal commands (10.7–10.9)"
  hold "submit one complete coding assignment end-to-end (10.10)"
  hold "test STOP and recovery after reboot (10.11)"
  if ask "Run final verification gate (scripts/verify-hermes.sh)?"; then
    bash "$SCRIPTS/verify-hermes.sh" || warn "Verification reported failures — fix before calling it done."
  fi
  close_phase 10 "Production deployment" || exec bash "$0"
fi

# ------------------------------------------------------------- summary -------
banner "SETUP SUMMARY"
ALL_DONE=1
for n in 1 2 3 4 5 6 7 8 9 10; do
  if phase_done "$n"; then
    printf '  Phase %-2s ✅ DONE\n' "$n"
  else
    printf '  Phase %-2s ⏳ PENDING\n' "$n"; ALL_DONE=0
  fi
done
echo
if [[ "$ALL_DONE" == "1" ]]; then
  echo "🎉 All 10 phases complete. Hermes is production-ready — revisit RUNBOOK.md"
  echo "   for any items you marked done manually, and keep verifying after updates"
  echo "   ('hermes update' then scripts/verify-hermes.sh)."
else
  echo "Some phases are still pending. Re-run: bash start-here.sh — it resumes"
  echo "where you left off (progress: $STATE)."
fi