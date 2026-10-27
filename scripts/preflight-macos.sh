#!/usr/bin/env bash
# Read-only preflight diagnostics for the target Apple Silicon Mac.
# Never installs, never changes permissions, never prompts for a password.
set -euo pipefail

PASS=0; FAIL=0; WARN=0
ok()   { echo "✅ PASS  $*"; PASS=$((PASS+1)); }
bad()  { echo "❌ FAIL  $*"; FAIL=$((FAIL+1)); }
warn() { echo "⚠️  WARN  $*"; WARN=$((WARN+1)); }
info() { echo "ℹ️  INFO  $*"; }

echo "=== Phase 1 — Environment preflight ==="

# 1.1 OS + architecture
if [[ "$(uname -s)" == "Darwin" ]]; then
  ok "Operating system is macOS ($(sw_vers -productVersion 2>/dev/null || echo unknown))"
else
  bad "Not macOS (uname: $(uname -s)). This is the wrong host — run on the target Mac."
fi
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  ok "Architecture is arm64 (Apple Silicon)"
elif [[ "$ARCH" == "x86_64" ]]; then
  bad "Architecture is x86_64 — the official Hermes macOS installer supports Apple Silicon only"
else
  bad "Unexpected architecture: $ARCH"
fi

# 1.2 Xcode Command Line Tools
if xcode-select -p >/dev/null 2>&1; then
  ok "Xcode Command Line Tools: $(xcode-select -p)"
else
  bad "Xcode Command Line Tools missing — run: xcode-select --install (GUI prompt, then re-run this script)"
fi

# 1.3 Core developer tools
for t in git curl tar shasum; do
  if command -v "$t" >/dev/null 2>&1; then
    ok "$t available ($(command -v "$t"))"
  else
    bad "$t missing (required by the Hermes POSIX installer)"
  fi
done
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew available ($(brew --version | head -1))"
else
  warn "Homebrew missing — optional; install from https://brew.sh if you want the Brewfile"
fi
if command -v python3 >/dev/null 2>&1; then
  info "python3: $(python3 --version 2>&1) (Hermes manages its own runtime via PM)"
fi
if command -v node >/dev/null 2>&1; then
  info "node: $(node --version 2>/dev/null) (Hermes manages its own runtime via PM)"
fi

# 1.5 Chrome and IDEs
if [[ -d "/Applications/Google Chrome.app" ]]; then
  ok "Google Chrome installed in /Applications"
else
  warn "Google Chrome not found in /Applications (browser QA / manual testing)"
fi
if command -v code >/dev/null 2>&1 || [[ -d "/Applications/Visual Studio Code.app" ]]; then
  ok "VS Code present"
else
  warn "VS Code not found (Phase 6 IDE usage) — install manually if required"
fi

# 1.6 Workspace directory
WORKSPACE="${HERMES_WORKSPACE:-$HOME/Developer}"
if [[ -d "$WORKSPACE" && -w "$WORKSPACE" ]]; then
  ok "Workspace directory exists and is writable: $WORKSPACE"
elif [[ -d "$WORKSPACE" ]]; then
  bad "Workspace exists but is not writable: $WORKSPACE"
else
  info "Workspace not created yet: $WORKSPACE — create it with: mkdir -p \"$WORKSPACE\""
fi

# 1.7–1.9 Privacy permissions: only checkable after cua-driver exists (Phase 4).
if command -v hermes >/dev/null 2>&1; then
  if hermes computer-use doctor >/dev/null 2>&1; then
    ok "hermes computer-use doctor exits 0 (accessibility + screen recording OK)"
  else
    warn "hermes computer-use doctor reports problems — re-run it after Phase 4 for per-check detail"
  fi
else
  warn "Hermes not installed yet — Accessibility/Screen Recording grants (1.7–1.9) are checked in Phase 4 via 'hermes computer-use doctor'"
fi

# 1.10 Active logged-in GUI session (informational, macOS only)
if [[ "$(uname -s)" == "Darwin" ]]; then
  SESSION_USER="$(stat -f '%Su' /dev/console 2>/dev/null || echo unknown)"
  if [[ "$SESSION_USER" == "$(id -un)" ]]; then
    ok "Console session belongs to current user ($SESSION_USER) — GUI automation can work"
  elif [[ "$SESSION_USER" == "loginwindow" ]]; then
    bad "At the login screen — log in to the desktop before running the agent"
  else
    warn "Console session user is '$SESSION_USER', current user is '$(id -un)' — GUI access may fail"
  fi
else
  warn "Skipping console-session check (not macOS)"
fi

# Hermes install state (informational)
if command -v hermes >/dev/null 2>&1; then
  info "Hermes installed: $(hermes --version 2>/dev/null || echo 'version unknown')"
else
  info "Hermes not installed yet (Phase 2)"
fi

echo
echo "=== Summary: $PASS passed, $FAIL failed, $WARN warnings ==="
if [[ "$FAIL" -gt 0 ]]; then
  echo "🛑 Fix FAIL items before continuing."
  exit 1
fi
echo "✅ Phase 1 prerequisites OK (resolve WARN items as needed)."