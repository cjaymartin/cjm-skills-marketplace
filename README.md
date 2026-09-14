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
| [`research-ticket`](skills/research-ticket/SKILL.md) | 02 research | Reads the ticket, the code, the git history and prior tickets. Writes a brief. Asks the questions only you can answer. |
| [`red-green-e2e`](skills/red-green-e2e/SKILL.md) | 03 + 06 replicate | Writes a plain-English test case. Proves it fails before the fix, and passes after. |
| [`green-green-e2e`](skills/green-green-e2e/SKILL.md) | regression | Proves behavior that already works still works after a change. |
| [`tdd-implement`](skills/tdd-implement/SKILL.md) | 04 + 05 build | Unit tests first, at seams you agreed to. Then the code. |
| [`self-review`](skills/self-review/SKILL.md) | 07 self-review | Parallel reviewers across legitimacy, correctness, error handling, tests, security and style. |
| [`implement`](skills/implement/SKILL.md) | 02 → 07 | Runs the whole chain. Resumable. |
| `blind-e2e` | — | The engine. Not called directly. |

Installed as a plugin they are `/agent-sdlc:implement` and so on. Installed from a clone
by symlink they are the plain `/implement`. See [Install it](#install-it).

## How the chain runs

| # | Runs | Gate before the next step |
|---|---|---|
| 1 | `research-ticket` | You answer the open questions and confirm it is the right bug |
| 2 | `red-green-e2e red` | Blind verdict must be **FAIL** |
| 3 | `tdd-implement` | You agree the seams; you pick when two designs are offered |
| 4 | `red-green-e2e green` | Blind verdict must be **PASS** |
| 5 | You step through the proof by hand | You confirm |
| 6 | `self-review` | You read the findings |

Progress is written to `.sdlc/<ticket-id>/state.md` after every step, so `implement`
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

## Install it

Two commands.

```bash
claude plugin marketplace add cjaymartin/skillz
```

```bash
claude plugin install agent-sdlc@skillz
```

That is the whole install. Works over SSH against the private repo, no extra setup.

The skills then answer to `/agent-sdlc:implement`, `/agent-sdlc:research-ticket`, and so
on. Tab completion after `/agent-sdlc:` lists them.

### Install the two prerequisites too

`tdd-implement` and `self-review` call into these rather than restating them. Without
them those two skills still run, but they lose the method they delegate to.

```bash
claude plugin marketplace add anthropics/claude-plugins-official && claude plugin install superpowers@claude-plugins-official
```

```bash
claude plugin marketplace add mattpocock/skills && claude plugin install mattpocock-skills@mattpocock
```

### Check it worked

```bash
claude plugin list
```

You want `agent-sdlc@skillz` marked enabled.

**Then restart Claude Code.** A plugin install does not take effect in the session that
ran it — the installer says "Restart to apply changes" and it means it. Skills installed
this way stay unknown until you restart. This is different from the clone-and-symlink
path below, which picks up new skills in a running session after a short rescan.

After the restart, type `/agent-sdlc:` and look for six skills.

`blind-e2e` will **not** appear. It is marked not user-invocable on purpose — only the
other skills call it. Its absence is the install working, not failing.

### Updating

```bash
claude plugin marketplace update skillz && claude plugin update agent-sdlc@skillz
```

Restart Claude Code afterwards, same as for the install.

**This only works if the version changed.** `claude plugin update` compares the version
in `.claude-plugin/plugin.json`, not the commit. Push a change without bumping it and
the update reports "already at the latest version" and pulls nothing.

So every change that installed users should receive ends with:

```bash
scripts/release.sh 0.3.0
```

That bumps the version, commits, and pushes.

### Uninstalling

```bash
claude plugin uninstall agent-sdlc@skillz
```

## Working on the skills themselves

The plugin install gives you a **copy** in `~/.claude/plugins/cache/`. Editing that copy
is pointless — the next update overwrites it.

To edit the skills and have your edits live at once, install from a clone instead:

```bash
git clone git@github.com:cjaymartin/skillz.git ~/WebstormProjects/skillz
```

```bash
cd ~/WebstormProjects/skillz && scripts/link-skills.sh
```

That symlinks each skill into `~/.claude/skills/`. Edit the repo, the skill changes. No
reinstall and no restart — a new or edited skill registers after a short rescan. The
first call right after a change can still say "Unknown skill"; wait and try again.

You should see seven lines, each ending `OK`. The commands are then the plain
`/implement`, `/research-ticket` and so on, with no `agent-sdlc:` prefix.

Edits are live at once here, with no version bump. The version only matters for people
installing the plugin.

**Do not run both installs at once.** You would get every skill twice in the menu. Pick
one:

```bash
scripts/link-skills.sh --unlink     # drop the symlinks, keep the plugin
```

```bash
claude plugin uninstall agent-sdlc@skillz    # drop the plugin, keep the symlinks
```

If a symlinked skill never appears in the menu, symlink discovery has a known bug in
some Claude Code versions. Reinstall in copy mode and rerun it after every edit:

```bash
cd ~/WebstormProjects/skillz && scripts/link-skills.sh --copy
```

## Using it in a project

Nothing to add to the project. The skills create what they need:

| Path | Committed? | What |
|---|---|---|
| `docs/research/<ticket-id>.md` | yes | the research brief |
| `docs/test-cases/<ticket-id>-<slug>.md` | yes | the plain-English test case |
| `.sdlc/` | no | progress and run evidence |

`/implement` adds `.sdlc/` to the project's `.gitignore` the first time it runs.

Start a ticket:

```bash
/agent-sdlc:implement #123
```

Or a pasted ticket, or a path to a markdown file. It asks for what it needs.

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
