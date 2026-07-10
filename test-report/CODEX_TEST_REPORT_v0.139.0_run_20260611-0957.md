# Codex Termux 0.139.0 - Device Validation Report

- Date: 2026-06-11
- Package under test: `@mmmbuto/codex-cli-termux@0.139.0`
- Platform: Android/Termux on a physical ARM64 device
- Validation mode: AI-guided device checks

## Scope

Post-install validation of the current Termux candidate build on the device,
with focus on command surface, runtime smoke, and Termux-specific packaging
checks.

## Environment Summary

- Installed CLI version: `codex-cli 0.139.0`
- Installed exec wrapper version: `codex-exec 0.139.0`
- npm dist-tags at test time:
  - `stable`: `0.135.0`
  - `latest`: `0.138.0`
  - `next`: `0.139.0`
- `termux-open-url`: available
- Android ELF `RUNPATH`: `$ORIGIN` present for both wrappers
- Temporary workspace used: writable path under Termux temp storage

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
- `codex-exec --sandbox workspace-write --skip-git-repo-check --json 'Start a shell command that sleeps about 5 seconds and then prints DONE-WAIT-OK (for example: sleep 5 && echo DONE-WAIT-OK). Do not block the turn while it runs: launch it, then wait for it to finish, and report only its final stdout.'`
  - Reported `DONE-WAIT-OK`, confirming the exec/wait path on Android.

## Termux-Specific Checks

PASS

- Browser-login helper available: `termux-open-url`
- Both wrappers resolve sibling libraries with `RUNPATH=$ORIGIN`

## Failures And Blockers

No product blockers found.

## Final Verdict

PASS - `@mmmbuto/codex-cli-termux@0.139.0` is validated on the device.
