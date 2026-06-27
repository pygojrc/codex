#!/usr/bin/env node

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// The platform package no longer ships a standalone `codex-exec` binary: the
// `codex-exec` command dispatches the single bundled `codex` binary with the
// `exec` subcommand, which uses the same ExecCli. Behavior is identical while
// the package drops one V8-linked binary (~150 MB).
const binaryPath = join(__dirname, 'codex');
const args = ['exec', ...process.argv.slice(2)];

const TERMUX_PREFIX = process.env.PREFIX || '/data/data/com.termux/files/usr';

function sanitizeLdLibraryPath(binDir) {
  const blocked = new Set([
    `${TERMUX_PREFIX}/lib`,
    `${TERMUX_PREFIX}/libexec`,
    '/data/data/com.termux/files/usr/lib',
    '/data/data/com.termux/files/usr/libexec'
  ]);

  const extraPaths = (process.env.LD_LIBRARY_PATH || '')
    .split(':')
    .filter((entry) => entry && !blocked.has(entry));

  return [binDir, ...extraPaths].join(':');
}

const env = { ...process.env, CODEX_MANAGED_BY_NPM: '1' };
const binDir = __dirname;
env.CODEX_SELF_EXE = binaryPath;
env.LD_LIBRARY_PATH = sanitizeLdLibraryPath(binDir);

const child = spawn(binaryPath, args, {
  stdio: 'inherit',
  env
});

child.on('exit', (code) => {
  process.exit(code);
});
