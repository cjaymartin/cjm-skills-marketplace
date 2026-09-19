#!/usr/bin/env node
// Keep this checkout, and the command it runs, level with its upstream branch.
//
//   watch-origin.mjs [--interval SEC] [--install "CMD"] [--once] -- CMD...
//
// Every SEC seconds (default 60) it fetches. When the upstream moved and this branch can
// fast-forward, it pulls with --ff-only, reinstalls if a lockfile or package.json changed,
// and restarts CMD. It never touches a dirty tree and never merges: it says what is in the
// way, once, and keeps watching. --once looks once, runs no command, and exits.
//
// The install command comes from the lockfile unless --install sets it:
//   pnpm-lock.yaml -> pnpm install --frozen-lockfile   package-lock.json -> npm ci
//   yarn.lock -> yarn install --frozen-lockfile        bun.lock(b) -> bun install --frozen-lockfile

import { spawn, spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';

const LOCKS = [
  ['pnpm-lock.yaml', 'pnpm install --frozen-lockfile'],
  ['package-lock.json', 'npm ci'],
  ['yarn.lock', 'yarn install --frozen-lockfile'],
  ['bun.lock', 'bun install --frozen-lockfile'],
  ['bun.lockb', 'bun install --frozen-lockfile'],
];
const MANIFESTS = new Set(['package.json', 'pnpm-workspace.yaml', ...LOCKS.map(([f]) => f)]);

function parse(argv) {
  const o = { interval: 60, install: null, once: false, command: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--') { o.command = argv.slice(i + 1); break; }
    else if (a === '--once') o.once = true;
    else if (a === '--interval') o.interval = Number(argv[++i]);
    else if (a === '--install') o.install = argv[++i];
    else { o.command = argv.slice(i); break; }
  }
  if (!Number.isInteger(o.interval) || o.interval < 1) throw new Error('--interval wants whole seconds');
  if (!o.once && o.command.length === 0) throw new Error('give a command to run after --, or use --once');
  return o;
}

function git(args) {
  const r = spawnSync('git', args, { encoding: 'utf8' });
  if (r.error) throw r.error;
  if (r.status !== 0) throw new Error((r.stderr || r.stdout).trim().split('\n')[0] || `git ${args[0]} failed`);
  return r.stdout.trim();
}

const installCommand = (o) => o.install ?? LOCKS.find(([f]) => existsSync(f))?.[1] ?? null;

let said = null;
const sayOnce = (key, text) => { if (said !== key) { said = key; console.log(text); } };

// Returns true when it pulled.
function poll(o) {
  try { git(['fetch', '--quiet']); } catch (e) {
    sayOnce('offline', `Could not reach origin: ${e.message}. Still watching.`);
    return false;
  }
  let ahead, behind, remote;
  try {
    [ahead, behind] = git(['rev-list', '--left-right', '--count', 'HEAD...@{u}']).split(/\s+/).map(Number);
    remote = git(['rev-parse', '@{u}']);
  } catch {
    sayOnce('no-upstream', 'This branch tracks no upstream. Set one: git branch --set-upstream-to origin/<branch>');
    return false;
  }
  if (behind === 0) { said = null; return false; }
  if (ahead > 0) {
    sayOnce(`diverged-${remote}`, `This branch and origin split (${ahead} here, ${behind} there). A merge is your call. Nothing pulled.`);
    return false;
  }
  const dirty = git(['status', '--porcelain']);
  if (dirty) {
    sayOnce(`dirty-${remote}`, `origin moved but the tree is not clean, so nothing was pulled. In the way:\n${dirty}`);
    return false;
  }
  const local = git(['rev-parse', 'HEAD']);
  const changed = git(['diff', '--name-only', `${local}..${remote}`]).split('\n').filter(Boolean);
  git(['merge', '--ff-only', '--quiet', '@{u}']);
  said = null;
  console.log(`Pulled ${local.slice(0, 7)} -> ${remote.slice(0, 7)}, ${changed.length} file(s) changed.`);
  const install = installCommand(o);
  if (install && changed.some((p) => MANIFESTS.has(p.split('/').pop()))) {
    console.log(`A manifest changed. Running: ${install}`);
    spawnSync(install, { shell: true, stdio: 'inherit' });
  }
  return true;
}

let o;
try { o = parse(process.argv.slice(2)); } catch (e) {
  console.error(`watch-origin: ${e.message}`);
  process.exit(2);
}
if (o.once) { poll(o); process.exit(0); }

let child = null;
let stopping = false;
const start = () => {
  const c = spawn(o.command[0], o.command.slice(1), { stdio: 'inherit', detached: true });
  c.on('error', (e) => console.log(`Could not start ${o.command[0]}: ${e.message}. Still watching.`));
  c.on('exit', (code, signal) => {
    if (!signal && code) console.log(`${o.command.join(' ')} exited ${code}. Still watching.`);
    if (child === c) child = null;
  });
  child = c;
};
// detached makes the child a group leader, so the signal reaches the dev server it spawned.
// Wait for the exit, so the restarted command finds its port free.
const stop = () => new Promise((resolve) => {
  const c = child;
  child = null;
  if (!c || c.exitCode !== null || c.signalCode !== null) return resolve();
  const kill = (sig) => { try { process.kill(-c.pid, sig); } catch { /* already gone */ } };
  const timer = setTimeout(() => kill('SIGKILL'), 5000);
  c.once('exit', () => { clearTimeout(timer); resolve(); });
  kill('SIGTERM');
});
const finish = async () => { stopping = true; await stop(); process.exit(0); };
process.on('SIGINT', finish);
process.on('SIGTERM', finish);

console.log(`Watching origin every ${o.interval}s. Running: ${o.command.join(' ')}. Ctrl-C stops both.`);
start();
const tick = async () => {
  if (stopping) return;
  try {
    if (poll(o)) { await stop(); start(); }
  } catch (e) {
    // An index.lock from the user's own git command, for example. Try again next time.
    console.log(`git failed: ${e.message}. Nothing changed. Still watching.`);
  }
  setTimeout(tick, o.interval * 1000);
};
tick();
