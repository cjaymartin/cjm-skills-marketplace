# cjm-skills-marketplace

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
| [`implement`](skills/implement/SKILL.md) | 02 → 07 | Runs the whole chain. Stops at every human gate. Resumable. |
| [`independent-implement`](skills/independent-implement/SKILL.md) | 02 → 07 | The same chain unattended. Guesses cheap answers, logs every one, stops only when a wrong guess would be expensive. |
| `blind-e2e` | — | The engine. Not called directly. |

### Everyday skills

These came out of a search of 657 past chats for work the agent kept doing by hand.
Each one is a script, so it costs few tokens and does the same thing every time.

| Skill | What it does |
|---|---|
| [`serve`](skills/serve/SKILL.md) | Starts a server on a free port, waits until it answers, and stops only what it started. Replaces nohup, curl loops, and kill by port. |
| [`test-summary`](skills/test-summary/SKILL.md) | Runs tests once, prints the totals and the failures, and keeps the full log. No second run because `tail` cut the error off. |
| [`pr-status`](skills/pr-status/SKILL.md) | Says whether a PR can merge, the result of each check, and why CI failed. `--wait` replaces sleep loops. |
| [`attach-images`](skills/attach-images/SKILL.md) | Puts screenshots on a side branch with no browser, and prints links for a PR or issue. |
| [`watch-origin`](skills/watch-origin/SKILL.md) | Keeps a checkout and its dev server level with the remote branch. You call it by name. |
| [`skillhound`](skills/skillhound/SKILL.md) | Runs that search again: finds repeated work in your chats that belongs in a skill or a script. You call it by name. |
| [`jev`](skills/jev/SKILL.md) | Sends a multiple-choice or yes/no decision to Jev, a cheap decision model from TypeSafe. The agent takes the pick when Jev is sure, and decides itself when Jev is not. Needs a TypeSafe key. |
| [`local-secrets`](skills/local-secrets/SKILL.md) | Keeps every secret in one gitignored `.env.local` that you fill in by hand. The agent adds each key with the steps to get it, checks which keys are set, and never sees the values. No more "paste your key here" commands. |

The SDLC skills share one script, [`skills/implement/scripts/sdlc.sh`](skills/implement/scripts/sdlc.sh).
It saves and gates blind verdicts, checks test-case hashes, makes base-branch checkouts
for red runs, prints resume status, and builds self-review packets.
`research-ticket` reads tickets with [`fetch-ticket.sh`](skills/research-ticket/scripts/fetch-ticket.sh).

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

To run the same chain without the stops, use `independent-implement`. See
[Running it unattended](#running-it-unattended).

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

## The writing standard

Everything these skills produce gets written in **Simplified Technical English**
(ASD-STE100): short sentences, active voice, one word for one meaning, the answer first.

This is not a style preference. A test case that reads two ways returns BLOCKED, and
BLOCKED costs a whole round. A research brief that buries its finding under qualifiers
gets skimmed, and the human gate it feeds gets rubber-stamped. Clear writing is what
makes the gates work.

**It applies automatically.** Installing this plugin adds a SessionStart hook that
injects [WRITING-STANDARD.md](WRITING-STANDARD.md) into every session — not only inside
the skills, but in every reply, document and commit message. Nobody has to remember to
ask for it.

The hook needs a fresh session before it fires. It fails silently: a missing or
unreadable standard file never breaks a session.

Each skill also carries the rule inline, so it still applies on the clone-and-symlink
install, where plugin hooks do not run.

The full 53 rules come from [SimpleEnglish](https://github.com/AminBlg/SimpleEnglish).
[WRITING-STANDARD.md](WRITING-STANDARD.md) is the short form for when that skill is not
installed.

## Running it unattended

`implement` stops at five human gates. `independent-implement` runs the same chain
without you.

The rule is rework cost, not importance. If a wrong guess costs under 20 minutes of agent
work to undo, it guesses, says so out loud, logs it, and carries on. If it costs more, it
stops and waits. This is ordinary agile practice: when the answer is not in the spec and
nobody is available, either choice is usually fine as long as it is written down.

Every guess lands in `.sdlc/<ticket-id>/assumptions.md` with the answer, the reason, the
rework estimate, and the earliest step it affects. The run ends with that list, most
expensive first:

```
| # | Question | Guessed | Rework if wrong | Re-runs from |
|---|---|---|---|---|
| A1 | Which date format for the export? | ISO 8601 | 5 min | implement |
| A2 | Should an empty cart show zero or an error? | zero | 15 min | red |
```

Change one by replying `A2 should be an error`. The skill re-enters at the step that
answer affects, runs forward from there, and re-checks every later assumption that rested
on the old answer. It does not restart the chain.

**Autonomy never touches evidence.** The blind verdicts are unchanged. Red still has to
FAIL, green still has to PASS, and BLOCKED is still neither.

## Ticket sources

[`fetch-ticket.sh`](skills/research-ticket/scripts/fetch-ticket.sh) reads GitHub issues
and markdown files. Plain text falls back to
[`plain-text.md`](skills/research-ticket/ticket-sources/plain-text.md). Adding a source
means adding one branch to the script.

## Install it

Two commands.

```bash
claude plugin marketplace add cjaymartin/cjm-skills-marketplace
```

```bash
claude plugin install agent-sdlc@cjm-skills-marketplace
```

That is the whole install. Works over SSH against the private repo, no extra setup.

The skills then answer to `/agent-sdlc:implement`, `/agent-sdlc:research-ticket`, and so
on. Tab completion after `/agent-sdlc:` lists them.

### Install the four prerequisites too

```bash
claude plugin marketplace add anthropics/claude-plugins-official && claude plugin install superpowers@claude-plugins-official
```

```bash
claude plugin marketplace add mattpocock/skills && claude plugin install mattpocock-skills@mattpocock
```

```bash
claude plugin marketplace add AminBlg/SimpleEnglish && claude plugin install simple-english@simple-english
```

ponytail needs two separate commands. Its own README says so.

```bash
claude plugin marketplace add DietrichGebert/ponytail
```

```bash
claude plugin install ponytail@ponytail
```

| Prerequisite | Why |
|---|---|
| [superpowers](https://github.com/obra/superpowers) | `tdd-implement` delegates the red-green loop discipline to it |
| [mattpocock-skills](https://github.com/mattpocock/skills) | `tdd-implement` and `self-review` delegate test design and the two-axis review to it |
| [SimpleEnglish](https://github.com/AminBlg/SimpleEnglish) | carries all 53 ASD-STE100 rules, the approved vocabulary, and a word-choice linter |
| [ponytail](https://github.com/dietrichgebert/ponytail) | `tdd-implement` delegates "write the least code that passes" to it. It activates itself, so nothing here has to inject it |

ponytail runs two Node.js lifecycle hooks, so `node` must be on the non-interactive
shell's PATH. Without it the skills still work and the always-on activation stays quiet.

Without them those skills still run. They just lose the method they delegate to.

### Check it worked

```bash
claude plugin list
```

You want `agent-sdlc@cjm-skills-marketplace` marked enabled.

Then type `/agent-sdlc:` and look for fourteen skills.

**Give it a minute.** A newly installed plugin registers after a rescan, not
immediately, and the installer's "Restart to apply changes" overstates it. A call made
too early returns "Unknown skill". Waiting works; restarting also works and is faster to
be sure of.

**Hooks are the exception.** The writing standard below is injected by a SessionStart
hook, and a hook really does need a fresh session before it fires.

`blind-e2e` will **not** appear. It is marked not user-invocable on purpose — only the
other skills call it. Its absence is the install working, not failing.

### Updating

```bash
claude plugin marketplace update cjm-skills-marketplace && claude plugin update agent-sdlc@cjm-skills-marketplace
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
claude plugin uninstall agent-sdlc@cjm-skills-marketplace
```

## Working on the skills themselves

The plugin install gives you a **copy** in `~/.claude/plugins/cache/`. Editing that copy
is pointless — the next update overwrites it.

To edit the skills and have your edits live at once, install from a clone instead:

```bash
git clone git@github.com:cjaymartin/cjm-skills-marketplace.git ~/src/cjm-skills-marketplace
```

```bash
cd ~/src/cjm-skills-marketplace && scripts/link-skills.sh
```

That symlinks each skill into `~/.claude/skills/`. Edit the repo, the skill changes. No
reinstall and no restart — a new or edited skill registers after a short rescan. The
first call right after a change can still say "Unknown skill"; wait and try again.

You should see fourteen lines, each ending `OK`. The commands are then the plain
`/implement`, `/research-ticket` and so on, with no `agent-sdlc:` prefix.

Edits are live at once here, with no version bump. The version only matters for people
installing the plugin.

**Do not run both installs at once.** You would get every skill twice in the menu. Pick
one:

```bash
scripts/link-skills.sh --unlink     # drop the symlinks, keep the plugin
```

```bash
claude plugin uninstall agent-sdlc@cjm-skills-marketplace    # drop the plugin, keep the symlinks
```

If a symlinked skill never appears in the menu, symlink discovery has a known bug in
some Claude Code versions. Reinstall in copy mode and rerun it after every edit:

```bash
cd ~/src/cjm-skills-marketplace && scripts/link-skills.sh --copy
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

`scripts/test-scripts.sh` runs every script the skills call against throwaway repos. Run
it after any edit under `skills/*/scripts/`. `pr-status.sh` is the one it skips, because
it needs a real pull request.

`scripts/probes/` holds the probe skills that verify Claude Code's fork, symlink,
argument and tool-restriction behavior, plus three trial cases that verify `blind-e2e`
can still tell its three verdicts apart. Rerun them after a Claude Code upgrade or any
edit to `blind-e2e`.

## Not covered

Steps 08 to 11: another person's code review, QA, regression testing, release.
`self-review` is not a substitute for a second reader.
