# Codex Termux 0.142.0 - Device Validation Report

- Date: 2026-06-23
- Package under test: `@mmmbuto/codex-cli-termux@0.142.0`
- Platform: Android/Termux on a physical ARM64 device
- Validation mode: AI-guided device checks

## Scope

Post-install validation of the current Termux build on the device, following
`test-report/AI_GUIDED_TEST_SUITE.md` with the installed candidate version.

## Environment Summary

- Installed CLI version: `codex-cli 0.142.0`
- Installed exec wrapper version: `codex-exec 0.142.0`
- npm global package: `@mmmbuto/codex-cli-termux@0.142.0`
- npm dist-tags at test time:
  - `stable`: `0.140.0`
  - `latest`: `0.140.0`
  - `next`: `0.142.0`
- Browser-login helper available: `termux-open-url`
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

Note: the suite's literal `/tmp/codex-termux-completion.bash` redirection was
blocked because `/tmp` is owned by the Android shell user in this session. The
same completion command generated a 206033-byte bash completion file when
redirected to the writable Termux temporary workspace, so wrapper routing is
validated.

## Runtime Smoke

PASS

- `codex exec --skip-git-repo-check --ephemeral 'Reply with exactly: OK'`
  - Observed the expected `OK` response.
- `codex-exec --sandbox workspace-write --skip-git-repo-check --json 'Print current directory and list files. Do not modify files.'`
  - Reported the temporary workspace and listed the seed file.
- `codex-exec --sandbox workspace-write --skip-git-repo-check --json 'Create hello.txt with content hello-codex-termux, then read seed.txt and hello.txt back.'`
  - Created `hello.txt` and confirmed both file contents.
  - The model first attempted `apply_patch`, which was rejected by sandbox policy for the temporary path; direct shell write succeeded.
- `codex-exec --sandbox workspace-write --skip-git-repo-check --json 'Run one network check with curl -I https://www.google.com and report the first HTTP status line only.'`
  - Reported `HTTP/2 200`.
- `codex-exec --sandbox workspace-write --skip-git-repo-check --json 'Start a shell command that sleeps about 5 seconds and then prints DONE-WAIT-OK (for example: sleep 5 && echo DONE-WAIT-OK). Do not block the turn while it runs: launch it, then wait for it to finish, and report only its final stdout.'`
  - First attempt hit transient model capacity after launching the command.
  - Retry reported `DONE-WAIT-OK`, confirming the exec/wait path on Android.

## Termux-Specific Checks

PASS

- Browser-login helper available: `termux-open-url`
- Both wrappers resolve sibling libraries with `RUNPATH=$ORIGIN`

## Warnings

- npm emitted `Unknown user config "android_ndk_path"` during package queries.
  This is a local npm configuration warning and did not affect validation.

## Failures And Blockers

No product blockers found.

## Final Verdict

PASS - `@mmmbuto/codex-cli-termux@0.142.0` is validated on the device.
