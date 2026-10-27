# Hermes Autonomous Developer — Runbook

Operational checklist for the ten phases from the project brief. Execute **on the target Apple Silicon Mac**, logged into the desktop session that will run the agent.

> Guided mode: `bash start-here.sh` walks this runbook in order with prompts and saves/resumes progress. Use this document directly if you prefer to work the phases manually.

Rules for marking items done:

- `[x]` only after you have personally run the check and seen it pass on the Mac.
- `⚠ MANUAL` means a script cannot complete it; a human action in a GUI or with a service is required.
- `🔒 CREDENTIAL` means a secret must exist only in `~/.hermes/.env` or a password manager — never in this repo.
- `🛑 STOP` before proceeding if any check fails; fix it first.

---

## PHASE 1 — Mac preparation

- [ ] 1.1 Verify macOS version (Apple Silicon required for the official installer) — `scripts/preflight-macos.sh`
- [ ] 1.2 Verify Xcode Command Line Tools (`xcode-select -p`) — ⚠ MANUAL install prompt if missing
- [ ] 1.3 Verify Homebrew, Git, Python, Node.js — `brew bundle --file Brewfile`
- [ ] 1.4 Install/update developer dependencies (Brewfile)
- [ ] 1.5 Verify Chrome and installed IDEs (`code --version`, app list) — ⚠ MANUAL for non-brew IDEs
- [ ] 1.6 Configure developer workspace directory (choose a path; default `~/Developer`)
- [ ] 1.7 macOS Accessibility permission — ⚠ MANUAL, granted to the identity named by `hermes computer-use doctor` (after Phase 4 install)
- [ ] 1.8 macOS Screen Recording permission — ⚠ MANUAL, same identity
- [ ] 1.9 macOS Automation permission — ⚠ MANUAL, only when macOS prompts and you recognize the app
- [ ] 1.10 Confirm active logged-in desktop session (Mac awake, not at login screen)

EXIT: MacBook ready for native automation. Verify with `scripts/preflight-macos.sh` → all PASS.

## PHASE 2 — Hermes CLI installation

- [ ] 2.1 Install official Hermes Agent — `scripts/install-hermes.sh --install` (interactive; reads the official `install.sh`)
- [ ] 2.2 Configure AI model provider — ⚠ MANUAL `hermes model` (your choice; min 64K context)
- [ ] 2.3 Authenticate provider credentials — 🔒 CREDENTIAL stays in `~/.hermes/.env` / `auth.json`
- [ ] 2.4 Configure `terminal.backend = local` — `scripts/setup-hermes.sh`
- [ ] 2.5 Enable terminal/file operation toolsets — `hermes tools` (interactive)
- [ ] 2.6 Enable browser toolset — `hermes tools` (only if the browser prerequisite is configured)
- [ ] 2.7 Enable `computer_use` toolset — `hermes tools` → Computer Use (installs `cua-driver` if missing)
- [ ] 2.8 Enable persistent memory and skills — `hermes skills`, `hermes config`
- [ ] 2.9 Configure `SOUL.md` developer identity — copy/edit `SOUL.md` to `~/.hermes/SOUL.md`
- [ ] 2.10 Verify agent executes local commands — run `hermes` with a simple "run `uname -a`" prompt
- [ ] 2.11 Verify agent can create/edit project files — ask it to create a scratch file in the workspace, then confirm

EXIT: Hermes running locally on Mac. Verify with `scripts/verify-hermes.sh`.

## PHASE 3 — Telegram gateway

- [ ] 3.1 Create bot via **@BotFather** (`/newbot`) — ⚠ MANUAL
- [ ] 3.2 Secure bot token — 🔒 CREDENTIAL in `~/.hermes/.env` as `TELEGRAM_BOT_TOKEN`
- [ ] 3.3 Determine authorized Telegram user ID (trusted ID bot) — ⚠ MANUAL
- [ ] 3.4 Configure Telegram allowlist — `TELEGRAM_ALLOWED_USERS=<your numeric id>` — never empty
- [ ] 3.5 Run `hermes gateway setup`, select Telegram — interactive wizard
- [ ] 3.6 Review/enable tools available to Telegram — `hermes tools --platform hermes-telegram`
- [ ] 3.7 Verify message-to-agent execution — send a message from your allowlisted account
- [ ] 3.8 Enable tool progress reporting — `display.tool_progress` in config.yaml
- [ ] 3.9 Configure screenshot delivery — ask the bot for a screenshot; `MEDIA:` attachments must be host-readable
- [ ] 3.10 Test remote task submission — send a small task from your phone

EXIT: Telegram controls local Hermes session. Unauthorized users must be refused.

## PHASE 4 — Native computer use

- [ ] 4.1 Install `cua-driver` — `hermes computer-use install` (or via `hermes tools`)
- [ ] 4.2 Run diagnostics — `hermes computer-use doctor` must exit 0
- [ ] 4.3 Verify screen capture (`screen_capture_capability` PASS)
- [ ] 4.4 Verify macOS accessibility tree (`ax_capability` PASS)
- [ ] 4.5–4.11 Verify the screenshot-observe-act loop against Finder, Chrome, VS Code, Terminal — prompt Hermes through `computer_use` actions and confirm each lands on the intended element
- [ ] 4.12 Verify actions through fresh screenshots — confirm state changes after each action

EXIT: `hermes computer-use doctor` exits 0 and a GUI task completes via `computer_use`.

## PHASE 5 — Visible control (revised)

The original brief asks for physical cursor movement and human-like typing to disguise automation. That conflicts with Hermes' documented design: the supported `computer_use` path is **background** input (no cursor warp, no focus steal) with an optional overlay cursor. Recommended:

- [ ] 5.1–5.8 Use Hermes' native `computer_use` action vocabulary instead of custom input drivers
- [ ] 5.9 Window focus/switching via `computer_use` `focus_app`
- [ ] 5.10 Observe IDE/Chrome/Terminal activity — 🛑 Do not aim to make automated input appear human; keep the visible overlay or on-screen evidence of agent activity
- [ ] 5.11 Handle display scaling/multi-monitor through `computer_use` capture targets
- [ ] 5.12 Recover from unexpected dialogs — prompt-driven; never auto-click permission dialogs
- [ ] 5.13 STOP / kill switch — `bash stop-hermes.sh` (pauses Hermes + prints gateway status) or `hermes pause`; resume with `hermes resume`. `start-here.sh` runs this live pause→halt→resume test for you in Phase 5
- [ ] 5.14 Verify end-to-end GUI execution with the background path

If genuine human-like cursor/typing disguise is a hard requirement, pause and re-confirm the intent and policy implications before implementing it.

EXIT: GUI tasks execute; STOP (`hermes pause`) halts new work immediately.

## PHASE 6 — Software developer capabilities

- [ ] 6.1 Install development workflow skills — `hermes skills browse` / `hermes skills install <slug>`
- [ ] 6.2–6.4 Project discovery, codebase analysis, requirements-to-plan — workspace config + `SOUL.md` + skills
- [ ] 6.5–6.9 File creation/modification, CLI package management, Git branch/commit, IDE and browser usage, dependency installation — enabled via `hermes tools`
- [ ] 6.10–6.11 Automated testing, linting and build validation
- [ ] 6.12 Browser QA and debugging — browser toolset (host Chromium via PM)
- [ ] 6.13 Build error recovery — prompts/skills; verify with a deliberately failing build
- [ ] 6.14 GitHub PR creation — `gh` auth (🔒 CREDENTIAL) or MCP GitHub server
- [ ] 6.15–6.16 Deployment and rollback procedures — only with explicit confirmation; never autonomous deploys by default

EXIT: Agent completes a real development task in the workspace.

## PHASE 7 — Autonomous task execution

- [ ] 7.1–7.3 Parse Telegram task → resolve workspace → generate plan (natural Hermes behavior; verify)
- [ ] 7.4–7.5 Task status RUNNING → execute tools and GUI actions
- [ ] 7.6–7.8 Monitor results, debug recoverable failures, re-run affected tests
- [ ] 7.9 Record changed files and commits (Git history is the record)
- [ ] 7.10 Send completion report via Telegram
- [ ] 7.11 Task cancellation — `/stop` from Telegram; `hermes pause` globally
- [ ] 7.12 Serialize competing GUI tasks — only one `computer_use` session drives the desktop
- [ ] 7.13 Restore incomplete tasks after failure — Hermes sessions (`hermes sessions list`) + gateway delivery ledger

EXIT: Telegram request becomes a complete development execution workflow.

## PHASE 8 — Authorization and control

- [ ] 8.1–8.2 Session execution policies and workspace scope — config + approval mode (keep `manual` or `smart`)
- [ ] 8.3 One-time capability approval — approval once/session/always grants
- [ ] 8.4 Require approval for exceptional actions — never disable approvals for unattended work
- [ ] 8.5 Prevent unauthorized Telegram access — non-empty `TELEGRAM_ALLOWED_USERS`; verify a stranger is refused
- [ ] 8.6 Protect credentials and SSH keys — 🔒 secrets in `~/.hermes/.env` only; restrict file modes
- [ ] 8.7 Action/event audit logs — `hermes logs`, gateway logs (auto-redacted)
- [ ] 8.8 Emergency disable — `bash stop-hermes.sh` (i.e. `hermes pause`); for full disable also `hermes gateway stop`. Verify both, then `hermes resume` to re-enable

EXIT: Unauthorized access refused; emergency stop verified.

## PHASE 9 — Reporting and observability

- [ ] 9.1 Task acknowledgment on Telegram
- [ ] 9.2 Current activity reporting — `display.tool_progress: all`
- [ ] 9.3–9.4 Screenshot capture at milestones and Telegram attachments — ask bot "send me a screenshot"
- [ ] 9.5 Error and retry reporting — `hermes logs`
- [ ] 9.6 Git commit / PR reporting
- [ ] 9.7 Test result reporting
- [ ] 9.8 Final completion summary
- [ ] 9.9 Persistent execution history — `hermes sessions list` / `hermes insights`

EXIT: Remote visibility of agent activity.

## PHASE 10 — Production deployment

- [ ] 10.1 Install gateway service — `hermes gateway install` (per-user launchd)
- [ ] 10.2 Configure launch-at-login — ⚠ MANUAL: ensure the Mac user logs in at boot; check the launchd service's `RunAtLoad`
- [ ] 10.3 Automatic service recovery — launchd `KeepAlive`; verify with `hermes gateway status`
- [ ] 10.4 Power/sleep settings — ⚠ MANUAL: `sudo pmset -a sleep 0` (or caffeinate) so GUI work is possible; reversible
- [ ] 10.5 Verify GUI availability after login (reboot test)
- [ ] 10.6 Verify remote Telegram connectivity after reboot
- [ ] 10.7–10.9 Test Chrome, IDE editing, Terminal command execution
- [ ] 10.10 Test a complete coding assignment end to end
- [ ] 10.11 Test STOP and recovery — `hermes pause` / `hermes resume`
- [ ] 10.12 Validate end-to-end deployment

EXIT: Production-ready autonomous agent — every box above checked on the Mac.