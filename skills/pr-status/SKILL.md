---
name: pr-status
description: Reports whether a GitHub pull request can merge, the result of each CI check, and the log lines of each failed run. Use it to check a PR, wait for CI, or find out why CI is red. It replaces repeated gh pr view, gh pr checks, and gh run view calls and sleep loops.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/pr-status.sh *)
---

# PR status

```bash
${CLAUDE_SKILL_DIR}/scripts/pr-status.sh            # the PR for the current branch
${CLAUDE_SKILL_DIR}/scripts/pr-status.sh 42
${CLAUDE_SKILL_DIR}/scripts/pr-status.sh 42 --wait  # block until every check finishes
${CLAUDE_SKILL_DIR}/scripts/pr-status.sh 42 --repo owner/repo
```

It prints:

```
#42 Fix the cart total
state=OPEN mergeable=MERGEABLE merge_state=CLEAN review=APPROVED fix/cart -> main
https://github.com/owner/repo/pull/42
--- checks
success	test (CI)
failure	lint (CI)
--- failed run 123456 (full log: gh run view 123456 --log-failed)
job: lint
  step: Run pnpm lint
src/cart.ts:12:5 error 'total' is never reassigned
```

If every check passed and the PR is ready to merge, it exits 0. Ready means not a draft,
no conflicts, and no missing review. Otherwise it exits 1. It needs `gh` and `jq`.

## Reading it

- `mergeable=CONFLICTING` means the branch conflicts with the base. Merge the base in
  before anything else.
- `merge_state=BLOCKED` with green checks means a required review or rule is missing.
- `merge_state=BEHIND` means the base moved and the repository requires an up-to-date
  branch.
- A failed run with no log lines means GitHub kept no log for it. The job and step names
  still tell you where it failed.

Use `--wait` after a push, in place of a loop that sleeps and polls.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.
