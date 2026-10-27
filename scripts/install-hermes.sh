#!/usr/bin/env bash
# Explicitly gated installer for the official Hermes Agent CLI.
# Downloads nothing unless you pass --install. Run only on the target Mac.
set -euo pipefail

INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"

if [[ "${1:-}" != "--install" ]]; then
  cat <<EOF
Hermes CLI installer (gated)

Usage:  bash scripts/install-hermes.sh --install

Without --install this script only prints what would happen.

With --install it:
  1. Refuses to run on anything other than macOS arm64 (Apple Silicon)
  2. Downloads the official Hermes installer to a temp file (no silent curl|bash)
  3. Shows you the script, then asks for confirmation before executing it

The official installer may start interactive setup (hermes setup / hermes model).
Choose your own AI provider there and authenticate; provider choice is yours.
EOF
  exit 0
fi

# --- Guards -------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ Refusing: this host is $(uname -s), not macOS." >&2
  exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "❌ Refusing: architecture is $(uname -m); official macOS installer requires Apple Silicon." >&2
  exit 1
fi

echo "==> Downloading official installer to a temporary file..."
# BSD/macOS mktemp: use the -t form (trailing X's only; no .sh suffix after them)
TMP_SCRIPT="$(mktemp -t hermes-install)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
curl -fsSL "$INSTALL_URL" -o "$TMP_SCRIPT"

echo
echo "==> Installer downloaded ($(wc -l < "$TMP_SCRIPT") lines). First 40 lines:"
echo "----------------------------------------------------------------"
head -40 "$TMP_SCRIPT"
echo "----------------------------------------------------------------"
echo
printf "Review the full script at: %s\n" "$TMP_SCRIPT"
printf "Type 'yes' to execute the official Hermes installer, anything else to abort: "
read -r REPLY
if [[ "$REPLY" != "yes" ]]; then
  echo "Aborted. Nothing was installed."
  exit 0
fi

echo "==> Running installer (interactive stages may prompt)..."
bash "$TMP_SCRIPT"

echo
echo "==> Reloading shell environment and verifying..."
export PATH="$HOME/.local/bin:$PATH"
if command -v hermes >/dev/null 2>&1; then
  hermes --version || true
  echo "✅ Hermes CLI installed. Next: hermes model (choose provider), then scripts/setup-hermes.sh"
else
  echo "⚠️ 'hermes' not on PATH yet. Reload your shell (source ~/.zshrc) and re-check."
fi