# Hermes Autonomous Developer — macOS setup scaffold

This repository is a **setup scaffold and operator runbook** for the Apple Silicon Mac described in the project brief. It is not a configured or running agent yet.

> **Environment limitation:** this setup session is running Ubuntu Linux x86_64, not the target Mac. Mac-only installation, macOS Privacy & Security permissions, Telegram credentials, model authentication, GUI interaction, and launch-at-login cannot be completed or honestly verified here. The included scripts stop when run on a non-macOS host. Run them on the intended Mac while logged into its desktop.

## Goals and safety defaults

- Native Hermes CLI and gateway on the Mac; Telegram is restricted to the explicit numeric user allowlist.
- Workspace access is scoped to a directory you choose; terminal backend is `local` only because the Mac is the intended execution host.
- Keep Hermes' normal approval prompts enabled. Do **not** use `--yolo`, `/yolo`, `approvals.mode: off`, or a public Telegram allowlist for this unattended computer.
- Keep provider keys and `TELEGRAM_BOT_TOKEN` in Hermes' private `~/.hermes/.env`, never in this repository, Telegram messages, screenshots, or commits.
- Use Hermes' supported `computer_use` toolset and `cua-driver` diagnostics. Computer Use is a background interaction path: it does not move the physical cursor or steal focus. Do not add cursor/typing simulation intended to disguise automation as a human.
- Require a human to handle exceptional/destructive actions and macOS permission prompts. Keep the Mac awake and the user logged in for GUI-dependent tasks.

## Start on the Mac

One command runs the Phase 1 preflight and then walks every phase of `RUNBOOK.md` in order, prompting you at each step:

```sh
bash start-here.sh
```

- Quit anytime with `q`; it saves progress to `.setup-progress` and resumes where you left off on the next run.
- It refuses to run anywhere except an Apple Silicon Mac in a real terminal.
- It prompts before anything that installs, configures, or starts a service; manual GUI steps (macOS privacy grants, BotFather, reboot tests) are presented as confirmations so nothing is marked done that wasn't verified.

What it drives:

1. `scripts/preflight-macos.sh` — read-only Phase 1 environment check (fails fast)
2. Brewfile install (optional prompt) + workspace directory
3. `scripts/install-hermes.sh --install` — confirmation-gated official installer; provider choice and authentication (`hermes model`) are yours
4. `scripts/setup-hermes.sh` — local terminal backend + workspace scope, then `hermes tools` and `SOUL.md`
5. Telegram: guides @BotFather, runs `hermes gateway setup`, hard-checks the allowlist is non-empty, then message/screenshot/remote-task tests
6. Computer use: `hermes computer-use install` + `hermes computer-use doctor` (stops if any check fails) and GUI interaction tests
7. Phases 5–10 as prompted checklists, ending with `scripts/verify-hermes.sh`

Do not run `start-here.sh` in this Linux workspace — it is intended for the target Mac. You can also work `RUNBOOK.md` manually using the individual scripts.

## Project files

- `start-here.sh` — **single guided entrypoint**: preflight, then a prompted walk through all ten phases with resume support.
- `stop-hermes.sh` — **emergency stop**: runs `hermes pause` (halts all new work) and prints gateway status; resume with `hermes resume`.
- `RUNBOOK.md` — phase-by-phase checklist, manual gates, and completion criteria.
- `Brewfile` — optional Homebrew package/cask manifest for common developer prerequisites.
- `config/hermes-config.yaml.example` — non-secret Hermes configuration example.
- `SOUL.md` — concise developer-agent identity template.
- `scripts/preflight-macos.sh` — macOS/architecture/tool/workspace/desktop diagnostics; no installs or permission changes.
- `scripts/install-hermes.sh` — explicitly gated official Hermes CLI installer.
- `scripts/setup-hermes.sh` — configures local terminal scope and invokes official interactive setup flows.
- `scripts/verify-hermes.sh` — Hermes, gateway, and computer-use checks; reports unmet prerequisites.

## Official documentation

- [Hermes installation](https://hermes-agent.nousresearch.com/docs/getting-started/installation)
- [Hermes quickstart](https://hermes-agent.nousresearch.com/docs/getting-started/quickstart)
- [Hermes configuration](https://hermes-agent.nousresearch.com/docs/user-guide/configuration)
- [Tools and toolsets](https://hermes-agent.nousresearch.com/docs/user-guide/features/tools)
- [Computer Use](https://hermes-agent.nousresearch.com/docs/user-guide/features/computer-use)
- [Messaging gateway](https://hermes-agent.nousresearch.com/docs/user-guide/messaging)
- [Telegram setup](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/messaging/telegram.md)

## Completion status

The scaffold is created; the ten operational phases remain **not started** until run and verified on the target Mac. Mark a phase complete only after its exit checks in `RUNBOOK.md` pass on that machine.
