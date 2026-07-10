# Codex Termux 0.138.0 — Device Validation Report

- Date: 2026-06-09
- Package under test: `@mmmbuto/codex-cli-termux@0.138.0`
- Platform: Android/Termux on a physical ARM64 device
- Validation mode: AI-guided device checks

## Scope

Post-install validation of the current Termux candidate build on the device,
with focus on command surface, runtime smoke, and Termux-specific packaging
checks.

## Environment Summary

- Installed CLI version: `codex-cli 0.138.0`
- Installed exec wrapper version: `codex-exec 0.138.0`
- npm dist-tags at test time:
  - `latest`: `0.137.0`
  - `next`: `0.138.0`
  - `stable`: `0.135.0`
- `termux-open-url`: available
- Android ELF `RUNPATH`: `$ORIGIN` present for both wrappers
- Temporary workspace used: writable path under `<termux-home>`

## Command Surface

PASS

- `codex --help`
- `codex exec --help`
- `codex login --help`
- `codex logout --help`
- `codex resume --help`
- `codex mcp --help`
- `codex sandbox --help`
- `codex completion bash`

Note: the exact suite redirection target under `/tmp` was not writable in this
Termux environment, so completion generation was verified by redirecting to a
writable path under `<termux-home>`.

## Runtime Smoke

PASS

- `codex exec --skip-git-repo-check --ephemeral 'Reply with exactly: OK'`
  - Observed the expected `OK` response.
- `codex-exec --sandbox workspace-write --skip-git-repo-check --json 'Print current directory and list files. Do not modify files.'`
  - Reported the temporary workspace and listed the seed file.
- `codex-exec --sandbox workspace-write --skip-git-repo-check --json 'Create hello.txt with content hello-codex-termux, then read seed.txt and hello.txt back.'`
  - Created `hello.txt` and confirmed both file contents.
- `codex-exec --sandbox workspace-write --skip-git-repo-check --json 'Run one network check with curl -I https://www.google.com and report the first HTTP status line only.'`
  - Reported `HTTP/2 200`.

## Termux-Specific Checks

PASS

- Browser-login helper available: `termux-open-url`
- Both wrappers resolve sibling libraries with `RUNPATH=$ORIGIN`

## Failures And Blockers

No product blockers found.

One environmental deviation was observed:

- `/tmp` is not writable for the current Termux user on this device, so the
  suite's exact completion redirection target could not be used as written.
  Completion generation still succeeded when redirected to a writable path
  under `<termux-home>`.

## Final Verdict

PASS — `@mmmbuto/codex-cli-termux@0.138.0` is validated on the device.
