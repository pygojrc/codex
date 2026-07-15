#!/usr/bin/env bash
# Security review: fail closed on external artifacts and repository update channels.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; exit 1; }

contains() {
  local description="$1" pattern="$2" file="$3"
  grep -q -- "$pattern" "$file" || fail "$description"
  pass "$description"
}

not_contains() {
  local description="$1" pattern="$2" file="$3"
  if grep -q -- "$pattern" "$file"; then
    fail "$description"
  fi
  pass "$description"
}

PUBLIC_SANITIZED_TREE="${CODEX_PUBLIC_SANITIZED_TREE:-0}"
case "$PUBLIC_SANITIZED_TREE" in
  0|1) ;;
  *) fail "CODEX_PUBLIC_SANITIZED_TREE must be 0 or 1" ;;
esac
if [[ "$PUBLIC_SANITIZED_TREE" == 1 ]]; then
  [[ ! -e .forgejo && ! -L .forgejo ]] || fail "public tree must not contain .forgejo automation"
  pass "public tree excludes Forge-only automation"
fi

contains "browser login uses Termux URL opener" "termux-open-url" codex-rs/login/src/server.rs
contains "release profile uses thin LTO" 'lto = "thin"' codex-rs/Cargo.toml
contains "release profile uses bounded codegen units" "codegen-units = 16" codex-rs/Cargo.toml
contains "Android ELF uses sibling-library RUNPATH" 'link-arg=-Wl,-rpath,$ORIGIN' codex-rs/.cargo/config.toml

contains "update action opens repository release page" "https://github.com/pygojrc/codex/releases/latest" codex-rs/tui/src/update_action.rs
contains "update action uses Termux URL opener" '"termux-open-url"' codex-rs/tui/src/update_action.rs
not_contains "update action must not execute third-party npm package" "@mmmbuto" codex-rs/tui/src/update_action.rs
not_contains "update action must not execute npm install" "npm.*install" codex-rs/tui/src/update_action.rs
contains "update metadata uses repository API" "api.github.com/repos/pygojrc/codex/releases/latest" codex-rs/tui/src/updates.rs
contains "update prompt uses repository release page" "github.com/pygojrc/codex/releases/latest" codex-rs/tui/src/update_prompt.rs
contains "history notice uses repository release page" "github.com/pygojrc/codex/releases/latest" codex-rs/tui/src/history_cell/notices.rs
contains "doctor uses repository release API" "api.github.com/repos/pygojrc/codex/releases/latest" codex-rs/cli/src/doctor/updates.rs
not_contains "doctor must not recommend third-party npm package" "@mmmbuto" codex-rs/cli/src/doctor/updates.rs

contains "Android daemon resolves the running native executable" "std::env::current_exe()" codex-rs/app-server-daemon/src/managed_install.rs
not_contains "Android daemon path must not read CODEX_SELF_EXE" 'var_os("CODEX_SELF_EXE")' codex-rs/app-server-daemon/src/managed_install.rs
contains "daemon automatic updates remain disabled" "auto_update_enabled: false" codex-rs/app-server-daemon/src/lib.rs
contains "control socket is owner-only" "const CONTROL_SOCKET_MODE: u32 = 0o600" codex-rs/app-server-transport/src/transport/unix_socket.rs
contains "control socket parent uses private directory helper" "prepare_private_socket_directory" codex-rs/app-server-transport/src/transport/unix_socket.rs

contains "unsupported-lock fallback is explicitly classified" "ErrorKind::Unsupported" codex-rs/core/src/installation_id.rs
contains "Android PTY shim is target-gated" 'target_os = "android"' codex-rs/utils/pty/src/pty.rs
contains "Android PTY shim uses posix_openpt" "posix_openpt" codex-rs/utils/pty/src/pty.rs
contains "Android build vendors OpenSSL" 'target.aarch64-linux-android.dependencies' codex-rs/core/Cargo.toml
contains "Termux TLS uses explicit certificate roots" "tls_certs_only" codex-rs/rmcp-client/src/utils.rs
contains "Termux TLS roots come from webpki" "webpki_root_certs" codex-rs/rmcp-client/src/utils.rs
contains "Android clipboard path is disabled" 'cfg(not(target_os = "android"))' codex-rs/tui/src/clipboard_paste.rs

contains "V8 fetcher requires a manifest entry" "no checksum-pinned rusty_v8 Android artifact entry" scripts/fetch_rusty_v8_android.py
contains "V8 fetcher validates archive checksum" "archive checksum mismatch" scripts/fetch_rusty_v8_android.py
contains "V8 fetcher validates binding checksum" "binding checksum mismatch" scripts/fetch_rusty_v8_android.py
contains "V8 fetcher uses atomic partial downloads" '.part' scripts/fetch_rusty_v8_android.py

python3 - <<'PY'
import re
import tomllib
from pathlib import Path

root = Path('.')
lock = tomllib.loads((root / 'codex-rs/Cargo.lock').read_text())
versions = {p['version'] for p in lock['package'] if p['name'] == 'v8'}
assert len(versions) == 1, f'expected one v8 version, found {versions}'
version = next(iter(versions))
manifest = tomllib.loads((root / 'third_party/v8/android-artifacts.toml').read_text())
entry = manifest['versions'][version]['targets']['aarch64-linux-android']
for key in ('repository', 'release_tag', 'archive_sha256', 'binding_sha256'):
    assert isinstance(entry.get(key), str) and entry[key], f'missing {key}'
for key in ('archive_sha256', 'binding_sha256'):
    assert re.fullmatch(r'[0-9a-f]{64}', entry[key]), f'invalid {key}'
print(f'PASS  V8 {version} has a checksum-pinned Android artifact pair')
PY

python3 -m py_compile scripts/fetch_rusty_v8_android.py
pass "V8 fetcher passes Python syntax validation"

WORKFLOW=.github/workflows/termux-npm-build-publish.yml
contains "workflow builds Cargo lockfile exactly" "cargo build" "$WORKFLOW"
contains "workflow enforces Cargo lockfile" "--locked" "$WORKFLOW"
contains "workflow verifies patch inventory" "verify-patches.sh" "$WORKFLOW"
contains "workflow build job has read-only contents" "contents: read" "$WORKFLOW"
contains "workflow release job has write permission" "contents: write" "$WORKFLOW"
if grep -Eq 'uses: actions/(checkout|upload-artifact|download-artifact)@v[0-9]+' "$WORKFLOW"; then
  fail "GitHub-maintained actions must be pinned to immutable commit SHAs"
fi
pass "GitHub-maintained actions are pinned to immutable commit SHAs"

if grep -R -n -E '(curl|wget).*\|[[:space:]]*(sh|bash)' \
  codex-rs/tui/src/update_action.rs \
  codex-rs/app-server-daemon/src \
  scripts/fetch_rusty_v8_android.py; then
  fail "runtime/release paths must not pipe network content into a shell"
fi
pass "runtime/release paths do not pipe network content into a shell"

printf '\nAll Termux security and compatibility invariants are present.\n'
