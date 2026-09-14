# skillz

An agent-driven SDLC as Claude Code skills.

A ticket has eleven steps. Six of them belong to the developer alone: research it,
prove it is broken, build the tests, build the code, prove it is fixed, review your own
work. This repo fills those six, and chains them behind one command.

The point is not automation. It is to compress the typing **between** decisions, so one
person can hold several tickets at once. Five human decision points stay in the loop.

## The skills

| Skill | Ticket step | What it does |
|---|---|---|
| [`/research-ticket`](skills/research-ticket/SKILL.md) | 02 research | Reads the ticket, the code, the git history and prior tickets. Writes a brief. Asks the questions only you can answer. |
| [`/red-green-e2e`](skills/red-green-e2e/SKILL.md) | 03 + 06 replicate | Writes a plain-English test case. Proves it fails before the fix, and passes after. |
| [`/green-green-e2e`](skills/green-green-e2e/SKILL.md) | regression | Proves behavior that already works still works after a change. |
| [`/tdd-implement`](skills/tdd-implement/SKILL.md) | 04 + 05 build | Unit tests first, at seams you agreed to. Then the code. |
| [`/self-review`](skills/self-review/SKILL.md) | 07 self-review | Parallel reviewers across legitimacy, correctness, error handling, tests, security and style. |
| [`/implement`](skills/implement/SKILL.md) | 02 → 07 | Runs the whole chain. Resumable. |
| `blind-e2e` | — | The engine. Not called directly. |

## How the chain runs

| # | Runs | Gate before the next step |
|---|---|---|
| 1 | `research-ticket` | You answer the open questions and confirm it is the right bug |
| 2 | `red-green-e2e red` | Blind verdict must be **FAIL** |
| 3 | `tdd-implement` | You agree the seams; you pick when two designs are offered |
| 4 | `red-green-e2e green` | Blind verdict must be **PASS** |
| 5 | You step through the proof by hand | You confirm |
| 6 | `self-review` | You read the findings |

Progress is written to `.sdlc/<ticket-id>/state.md` after every step, so `/implement`
picks up where it stopped.

## Why "blind"

`blind-e2e` runs one test case in an isolated agent that **cannot see** the ticket, the
diff, or the source. `Read`, `Grep`, `Glob`, `Edit` and `Write` are removed from it.

An agent that has read the fix will confirm the fix. It knows what "working" should look
like, so it steers toward it. Blindness removes the steering.

It returns **three** verdicts, not two: PASS, FAIL, and BLOCKED. BLOCKED means it could
not run the case at all. Treating that as FAIL is how you manufacture proof of a bug
that is not there.

Test cases live in `docs/test-cases/` in the repo being worked on, and are committed.
They outlive the ticket and become regression coverage.

## Ticket sources

GitHub issues first, but the reader is swappable. One markdown file per source in
[`skills/research-ticket/ticket-sources/`](skills/research-ticket/ticket-sources):
GitHub issue, markdown file, plain text, and a stub for a future system. Adding a source
means adding one file.

## Prerequisites

- [superpowers](https://github.com/obra/superpowers)
- [mattpocock-skills](https://github.com/mattpocock/skills)

`tdd-implement` and `self-review` call into both rather than restating them.

## Install on this machine

```bash
scripts/link-skills.sh
```

Symlinks each skill into `~/.claude/skills/`. Edit the repo and the skill changes at
once, with no reinstall. New and edited skills register after a short rescan, not
immediately.

Use `scripts/link-skills.sh --copy` if symlinked skills ever fail to appear in the skill
list.

## Install anywhere else

```bash
claude plugin marketplace add <this repo>
claude plugin install agent-sdlc@skillz
```

Skills then answer to `/agent-sdlc:<name>`.

## Documents

- [Design spec](docs/superpowers/specs/2026-09-14-agent-sdlc-skills-design.md)
- [Implementation plan](docs/superpowers/plans/2026-09-14-agent-sdlc-skills.md)
- [Research: skill and plugin mechanics](docs/research/2026-09-14-skill-and-plugin-mechanics.md)
- [Probe results](docs/research/2026-09-14-mechanism-probes.md) — what was verified on this machine, and what failed

## Checks

`scripts/probes/` holds the probe skills that verify Claude Code's fork, symlink,
argument and tool-restriction behavior, plus three trial cases that verify `blind-e2e`
can still tell its three verdicts apart. Rerun them after a Claude Code upgrade or any
edit to `blind-e2e`.

## Not covered

Steps 08 to 11: another person's code review, QA, regression testing, release.
`self-review` is not a substitute for a second reader.
