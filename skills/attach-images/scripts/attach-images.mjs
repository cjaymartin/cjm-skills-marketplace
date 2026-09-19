#!/usr/bin/env node
// Put images where a GitHub issue or PR can link them, with no browser.
//
//   attach-images.mjs <ref> <file...>
//
// <ref> names the branch: `attachments/<ref>`, for example `pr-42` or `issue-7`.
// The images are committed there with git plumbing and a scratch index, so the working
// tree, the real index, and the current branch are never touched. The branch is never
// merged. Prints one URL per file, pinned to the commit so the links outlive the branch.

import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join } from 'node:path';

const EXTENSIONS = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg'];
const git = (args, env) =>
  execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], env: env ?? process.env }).trim();
const gitOrNull = (args) => {
  try { return git(args); } catch { return null; }
};
// Lowercase, URL-safe names: a percent-escape in a pasted link helps nobody.
const nameFor = (file) =>
  basename(file).toLowerCase().replace(/[^a-z0-9.-]+/g, '-').replace(/-+/g, '-').replace(/^[-.]+/, '');

const [ref, ...files] = process.argv.slice(2);
if (!ref || files.length === 0) {
  console.error('usage: attach-images.mjs <ref> <file...>   e.g. attach-images.mjs pr-42 before.png after.png');
  process.exit(2);
}
if (!/^[A-Za-z0-9._-]+$/.test(ref)) {
  console.error(`"${ref}" can use letters, digits, dot, dash and underscore only.`);
  process.exit(2);
}

// Report every bad file at once, so one run finds them all.
const problems = [];
const seen = new Map();
for (const file of files) {
  let isFile = false;
  try { isFile = statSync(file).isFile(); } catch { /* reported below */ }
  const name = nameFor(file);
  if (!isFile) problems.push(`${file}: no such file`);
  else if (!EXTENSIONS.some((e) => name.endsWith(e))) problems.push(`${file}: only ${EXTENSIONS.join(' ')}`);
  else if (seen.has(name)) problems.push(`${file} and ${seen.get(name)} would both be saved as ${name}`);
  else seen.set(name, file);
}
if (problems.length > 0) {
  console.error(problems.join('\n'));
  process.exit(1);
}

const branch = `attachments/${ref}`;
const remote = git(['remote', 'get-url', 'origin']);
const repo = /github\.com[:/]+([^/\s]+)\/([^/\s]+?)(?:\.git)?\/?$/.exec(remote);
gitOrNull(['fetch', '--quiet', 'origin', `+refs/heads/${branch}:refs/remotes/origin/${branch}`]);
const parent = gitOrNull(['rev-parse', '--verify', '--quiet', `refs/remotes/origin/${branch}`]);

const scratch = mkdtempSync(join(tmpdir(), 'attach-images-'));
try {
  const env = { ...process.env, GIT_INDEX_FILE: join(scratch, 'index') };
  if (parent) git(['read-tree', parent], env);
  for (const file of files) {
    const blob = git(['hash-object', '-w', '--', file]);
    git(['update-index', '--add', '--cacheinfo', `100644,${blob},${nameFor(file)}`], env);
  }
  const tree = git(['write-tree'], env);
  let commit = parent;
  if (!parent || tree !== git(['rev-parse', `${parent}^{tree}`])) {
    const msg = `Attachments for ${ref}\n\nImages only. This branch is never merged.`;
    commit = git(['commit-tree', tree, ...(parent ? ['-p', parent] : []), '-m', msg]);
    // --no-verify: the repo's pre-push hook (a test suite, say) has nothing to check in images.
    git(['push', '--quiet', '--no-verify', 'origin', `${commit}:refs/heads/${branch}`]);
    console.log(`pushed ${files.length} file(s) to ${branch} at ${commit.slice(0, 7)}`);
  } else {
    console.log(`${branch} already has these files, unchanged`);
  }
  for (const file of files) {
    const name = nameFor(file);
    // blob URL with ?raw=1: raw.githubusercontent.com links 404 on private repos for readers.
    console.log(repo ? `https://github.com/${repo[1]}/${repo[2]}/blob/${commit}/${name}?raw=1` : `${commit}:${name}`);
  }
} catch (error) {
  console.error(`could not publish: ${String(error.stderr || error.message).trim()}`);
  console.error('If the push was refused, someone else pushed to the branch. Run it again.');
  process.exitCode = 1;
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
