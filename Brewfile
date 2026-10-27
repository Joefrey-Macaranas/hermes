# Optional Homebrew manifest for the Hermes Autonomous Developer Mac.
# Install with: brew bundle --file Brewfile
# Homebrew itself: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# CLI prerequisites (POSIX Hermes installer needs git + curl)
brew "git"
brew "curl"
brew "jq"
brew "coreutils"

# GitHub CLI for PR workflows (Phase 6.14)
brew "gh"

# Language runtimes when you do not rely solely on Hermes' managed PM tools
# (unversioned aliases so brew bundle keeps working as Homebrew bumps versions)
brew "python"
brew "node"

# Chrome for manual QA; the Hermes browser toolset also uses its own managed Chromium
cask "google-chrome"

# Handy GUI automation/inspection utilities (optional)
brew "hammerspoon"   # only if you choose to use it for window inspection helpers