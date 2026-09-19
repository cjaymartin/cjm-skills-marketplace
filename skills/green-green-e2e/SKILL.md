---
name: green-green-e2e
description: Guards against regressions by running the same plain-English test cases through a source-blind agent before and after a change, requiring a pass both times. Use for refactors, rethemes, dependency bumps, framework migrations, or any change that must not alter existing behavior.
arguments: mode change_id
argument-hint: [before|after] [change-id]
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/../implement/scripts/sdlc.sh *)
---

# Green-green regression guard

Two runs of unchanged test cases, by an agent that cannot see the code. Both must pass.

## What this is for

Behavior that **already works** and must keep working. Refactors, rethemes, dependency
bumps, framework migrations.

Use `red-green-e2e` instead when a bug is being fixed: there the first run must fail.
Here the first run must pass. Picking the wrong one inverts every gate.

## Two modes

```
/green-green-e2e before <change-id>
/green-green-e2e after <change-id>
```

Mode: `$mode`. Change: `$change_id`.

`SDLC` below means `${CLAUDE_SKILL_DIR}/../implement/scripts/sdlc.sh`. After each blind
run, pass its output to the script unchanged:

```bash
SDLC verdict <change-id> <before|after> <absolute path to the case> <<'VERDICT'
<the blind output, exactly as returned>
VERDICT
```

It saves the output to `.sdlc/runs/<change-id>/`, records the case hash in before mode,
and checks it in after mode. Exit 0 means PASS, 1 means FAIL, 2 means BLOCKED, 3 means
the output was malformed, and 4 means the case changed since before mode.

## Before mode — establish the guard

1. **Pick or write the cases.** Cover the behavior most likely to break and most costly
   if it does. Write them to `docs/test-cases/<change-id>-<slug>.md`, following
   [the test case format](../red-green-e2e/test-case-format.md). A case that starts a
   server uses `docs/test-cases/lib/serve.sh`. If it is missing, copy it from
   `${CLAUDE_SKILL_DIR}/../serve/scripts/serve.sh`.
2. **Run one fork per case.** Call the Skill tool with `blind-e2e` once per case, each
   with its own path.
3. **Save each verdict** with `SDLC verdict <change-id> before <case path>`. Every case
   gates on PASS.

## A FAIL in before mode is not a regression

It means the behavior was already broken. That case cannot guard anything — it has
nothing to protect.

Report it and stop. Do not carry a known-broken case into after mode: a FAIL there
would look like a regression you caused, and you would spend the afternoon chasing a
break that predates you.

The human decides: drop the case, fix the case, or file the pre-existing break as its
own ticket.

## After mode — prove nothing broke

1. **Same files, unedited.**
2. **One fork per case**, same calls.
3. **Save each verdict** with `SDLC verdict <change-id> after <case path>`. Every case
   gates on PASS. Exit 4 means the case changed since before mode, so that case proves
   nothing.

## One fork per case, always

Never hand several cases to one blind agent. A case that blocks or fails pollutes the
context of every case after it in that run — the agent starts looking for trouble, and
the later verdicts stop being independent.

Separate forks cost more. Independence is what you are buying.

## Reporting a regression

A FAIL in after mode, on a case that passed in before mode, is a regression. Report:

- **Which case** — its title and path.
- **Which step** — the numbered step where the two runs diverged.
- **Before and after side by side** — the STEPS OBSERVED and EVIDENCE lines from both
  verdicts, so the difference is visible without rerunning anything.

Do not diagnose the cause. That is the next piece of work, and it starts from a clean
reading of what changed, not from a guess written into the report.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.

A sentence that can be read two ways costs a round here. Call the `simple-english` skill
if it is installed. Short form: [WRITING-STANDARD.md](https://github.com/cjaymartin/cjm-skills-marketplace/blob/main/WRITING-STANDARD.md)
