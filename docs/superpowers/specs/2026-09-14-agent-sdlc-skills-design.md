# Design: agent-driven SDLC skills

Date: 2026-09-14
Status: **built** on 2026-09-14. All seven skills exist and are installed.
Repo: `cjm-skills-marketplace` (GitHub, `cjaymartin/cjm-skills-marketplace`)
Author: C. Jay Martin

## Contents
- Goal
- Scope
- The skills
- Artifacts on disk
- Data flow
- The blind test, in detail
- Human decision points
- Error handling
- Ticket sources
- Install and packaging
- Testing the skills
- Verify at build time
- Out of scope

---

## Goal

Fill steps 02 through 07 of the ticket lifecycle — the developer's own block — with skills that chain into one command. The eleven steps below are the lifecycle this repo was built against.

The eleven steps:

```
01 Report ticket
02 Research ticket        <- skills start here
03 Replicate failure
04 Build tests
05 Build code
06 Replicate success
07 Review own code        <- skills end here
08 Code review
09 QA
10 Regression testing
11 Release
```

The point of the chain is not full automation. It is to compress the typing **between** human decisions so one engineer can hold several tickets at once. The human keeps every decision.

## Scope

Seven skills plus supporting reference files. Generic: no employer names, no Jira, no product names. They must work in any repo on this machine.

Prerequisites, already installed:

- `superpowers` 6.3.0 at `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.3.0`
- `mattpocock-skills` 1.2.3 at `~/.claude/plugins/cache/mattpocock/mattpocock-skills/1.2.3`

We reuse those rather than rewrite them. See "Composition" under each skill.

---

## The skills

Directory names are the slash commands. Every skill sets `name` equal to its directory name so the repo works both as symlinked personal skills and as an installed plugin.

### 1. `research-ticket` — step 02

**Does:** turns a ticket reference into a research brief the rest of the chain can trust.

**Input:** a ticket reference. A GitHub issue number or URL, a path to a markdown file, or pasted text.

**Steps:**
1. Resolve the ticket through a ticket-source adapter (see "Ticket sources").
2. Read the repo: the code paths named or implied, `CONTEXT.md` and ADRs if present, `git log` and `git blame` around the suspect area.
3. Search for the change that introduced the behavior, when the ticket is a bug.
4. Search for prior tickets and prior fixes touching the same area.
5. For anything external — a library's real behavior, an API contract — delegate to `mattpocock-skills:research` so primary sources get read in the background.
6. Write the brief.
7. Ask the human the open questions. Stop there.

**Output:** `docs/research/<ticket-id>.md` with these sections: Ticket, Claimed behavior, Expected behavior and its backing, Suspect code paths, History, Prior art, Open questions, Recommendation.

**"Backing" is required.** The brief must name why the expected behavior is correct: a spec line, a version where it worked, the commit that broke it, or evidence of client impact. If none exists, the brief says so and the recommendation is "this may not be a bug". This is the legitimacy check pulled forward from review.

**Composition:** calls `mattpocock-skills:research` for external facts.

**Frontmatter:** `argument-hint: [ticket-ref]`.

---

### 2. `blind-e2e` — the shared engine

**Does:** runs one plain-English test case in an isolated subagent that cannot see the ticket, the diff, or the source, and reports PASS, FAIL, or BLOCKED with evidence.

**Input:** a path to a test case file under `docs/test-cases/`.

**Frontmatter:**
```yaml
context: fork
agent: general-purpose
background: false
user-invocable: false
disallowed-tools: Read, Grep, Glob, Edit, Write, NotebookEdit
argument-hint: [test-case-path]
```

The test case is injected into the fork's prompt with `` !`cat "$ARGUMENTS"` ``, so the fork needs no file-read tool. `disallowed-tools` then removes every tool that could reach the source.

Positional `$1` does **not** interpolate inside a `` !`...` `` injection — it resolves to an empty string. Use `$ARGUMENTS`, or a named argument declared in frontmatter. See [the probe results](../../research/2026-09-14-mechanism-probes.md).

The restriction is enforced at invocation, not by hiding the tool: the fork still sees `Read` in its tool list and gets denied on use. So the skill says up front that those tools will be denied, to save the fork a wasted turn.

**Bash stays allowed** because the fork must start the app. The SKILL.md instructs the fork: run only commands the test case names, and never read source files. That is instruction, not enforcement, and the spec records it as a known soft edge.

**Output:** a verdict block **returned as text** to the caller. The fork does not write it — `Write` is on its disallowed list, on purpose. The calling skill persists it to `.sdlc/runs/<ticket-id>/<step>-<timestamp>.md`. Screenshots are written by the browser tool itself, which is not the `Write` tool, so evidence capture still works.

```
VERDICT: PASS | FAIL | BLOCKED
TEST CASE: <path>
STEPS OBSERVED:
  1. <what was done> -> <what was seen>
EVIDENCE: <screenshot paths, output, URLs>
REASON: <one sentence; required for FAIL and BLOCKED>
```

**Three verdicts, not two.** BLOCKED means the agent could not run the case — app would not start, credentials missing, a step was ambiguous. BLOCKED is never treated as FAIL. Collapsing them is how a red gate produces a false positive.

**Composition:** none. This is a leaf.

---

### 3. `red-green-e2e` — steps 03 and 06

**Does:** proves the bug is real before the fix, and proves it is gone after.

Two modes, chosen by the first argument:

```
/red-green-e2e red <ticket-id>
/red-green-e2e green <ticket-id>
```


**`red` mode:**
1. Find or write the test case at `docs/test-cases/<ticket-id>-<slug>.md`, using the format in `test-case-format.md`.
2. Call `blind-e2e` on it.
3. Gate: the verdict must be **FAIL**. That is the proof the bug exists.
4. PASS at this gate means one of three things — the bug is not reproducible, the test case is wrong, or it is not a bug. Stop and put the three to the human.
5. BLOCKED means fix the setup section and rerun. Never a pass.

**`green` mode:**
1. Read the same test case file. Do not edit it. Editing the case between red and green destroys the proof.
2. Call `blind-e2e`.
3. Gate: the verdict must be **PASS**.
4. FAIL returns control to `tdd-implement`.

**Composition:** calls `blind-e2e`.

---

### 4. `green-green-e2e` — regression guard

**Does:** proves work already shipped still works after a change. For refactors, rethemes, and dependency bumps.

1. Pick or write test cases for behavior that works **today**.
2. Call `blind-e2e` before the change. Gate: **PASS**. A FAIL here means the behavior was already broken, so it is not a valid guard — report and stop.
3. The change happens.
4. Call `blind-e2e` on the same untouched cases. Gate: **PASS**.
5. A FAIL on the second run is a regression. Report which case, which step, with the before-and-after evidence side by side.

Accepts several test cases and runs them one fork each, so one broken case cannot poison another's context.

**Composition:** calls `blind-e2e`.

---

### 5. `tdd-implement` — steps 04 and 05

**Does:** builds the fix test-first.

1. Read the research brief from `docs/research/<ticket-id>.md`.
2. Propose the seams to test. **Stop and get the human's agreement.** No test is written at an unagreed seam.
3. Loop, one vertical slice at a time: one failing unit test, then the smallest code that passes it. Never all tests then all code.
4. Run typecheck and the touched test files every slice. Run the full suite once at the end.
5. When two designs are both reasonable, stop and put both to the human. Do not pick silently.

**Composition:** invokes `superpowers:test-driven-development` for the loop discipline and `mattpocock-skills:tdd` for what a good test is, where seams go, and the anti-patterns. This skill adds only the ticket wiring and the stop points.

---

### 6. `self-review` — step 07

**Does:** reviews our own work before a human ever sees it.

Spawns parallel review subagents, each with a clean context, then aggregates without reranking across axes.

Axes:

| Axis | Question |
|---|---|
| Legitimacy | Was this really a bug? Is the expected behavior backed by a spec, a working version, a breaking commit, or client impact? Working as designed is not a bug. |
| Correctness | Empty, null, boundary, and unusual inputs. |
| Error handling | Surfaced or swallowed? Silent failures, misleading messages, dead handlers. |
| Tests | Do they assert the behavior, or pass for the wrong reason? Were they red-greened? Flaky or brittle? Gaps on the headline behavior and its failure path. |
| Security and performance | New risk of exposure or slowdown. |
| Style and accuracy | Consistent with surrounding code. Comments that match the code. Documentation claims spot-checked. |

The full checklist lives in `review-checklist.md` next to the SKILL.md.

**Composition:** invokes `mattpocock-skills:code-review` for its two-axis Standards and Spec pass plus the Fowler smell baseline. `self-review` adds the Legitimacy axis, which nothing else covers.

---

### 7. `implement` — the orchestrator, steps 02 to 07

**Does:** runs the whole chain on one ticket.

`disable-model-invocation: true`. It runs when the user asks, never on its own.

Sequence:

| # | Action | Gate |
|---|---|---|
| 1 | `research-ticket` | Human answers the open questions and confirms it is the right bug |
| 2 | `red-green-e2e red` | Blind verdict must be FAIL |
| 3 | `tdd-implement` | Human agrees the seams; human picks between designs when asked |
| 4 | `red-green-e2e green` | Blind verdict must be PASS |
| 5 | Human steps through the proof by hand | Human confirms |
| 6 | `self-review` | Human reads the findings |

**Resumable.** State lives at `.sdlc/<ticket-id>/state.md` as a checklist with the artifact path for each finished step. Re-running `/implement <ticket-id>` reads that file, reports where it stopped, and continues. This is what makes several tickets in parallel practical.

**Name clash, accepted:** `mattpocock-skills` also ships `implement`. Theirs stays reachable as `/mattpocock-skills:implement`. The bare `/implement` becomes ours.

---

## Artifacts on disk

**`<ticket-id>` is defined once and used everywhere:** the issue number for a GitHub source (`gh-123`), the file basename for a markdown source, and a slug the human confirms for pasted text. `research-ticket` decides it, writes it into the brief, and every later skill reads it from there rather than deriving it again.

Inside the repo being worked on, not this one:

| Path | Committed? | What |
|---|---|---|
| `docs/research/<ticket-id>.md` | yes | the research brief |
| `docs/test-cases/<ticket-id>-<slug>.md` | yes | the plain-English test case |
| `.sdlc/<ticket-id>/state.md` | no | orchestrator progress |
| `.sdlc/runs/<ticket-id>/*.md` | no | blind run verdicts and evidence |

Test cases are committed on purpose. They are the by-product that feeds a regression suite later.

`implement` adds `.sdlc/` to the target repo's `.gitignore` if it is not already there.

---

## Data flow

```
ticket ref
   |
   v
[research-ticket] --adapter--> ticket text
   |                                 
   +--> docs/research/<id>.md --> HUMAN GATE 1
   |
   v
[red-green-e2e red]
   |
   +--> docs/test-cases/<id>-<slug>.md
   |        |
   |        v
   |    [blind-e2e] (forked, blind) --> VERDICT
   |        must be FAIL
   v
[tdd-implement] --> HUMAN GATE 2 (seams) --> code + unit tests
   |                HUMAN GATE 3 (design choice, when it arises)
   v
[red-green-e2e green]
   |        same test case file, unedited
   |        v
   |    [blind-e2e] --> VERDICT, must be PASS
   v
HUMAN GATE 4 (steps through it by hand)
   |
   v
[self-review] --> parallel review subagents --> findings --> HUMAN GATE 5
```

---

## The blind test, in detail

### Why blind

An agent that has read the fix will confirm the fix. It knows what "working" is supposed to look like, so it steers toward it and reports success. That is a false green. It also produces false reds when it "knows" the bug and finds a symptom that is not the reported one.

Blindness removes the steering. The fork's only knowledge of the world is the test case.

### Test case format

One markdown file, three required sections. Full template in `red-green-e2e/test-case-format.md`.

```markdown
# <short title>

## Setup
How to start the app. Exact commands. The URL. Any login to use.
Everything needed to reach the starting screen.

## Steps
1. <one action a person could do>
2. <next action>

## Expected
What should be seen after the last step. One observable outcome.
```

Rules:
- Plain English. No selectors, no function names, no file paths into source.
- The Expected section describes what a **user** sees, never what the code does.
- Never mention the bug, the ticket, or the fix. The fork must not know which way the answer is supposed to fall.
- Setup must be complete. An incomplete Setup produces BLOCKED, and BLOCKED wastes a round.

### Tools the fork may use

Whatever the case needs. Usually a browser: Playwright MCP is installed on this machine. Sometimes a shell command or an HTTP call. The skill does not prescribe one driver.

---

## Human decision points

Five:

1. **After research.** The agent says the behavior was intended, or found a different bug than the one reported. Continue or not?
2. **Before replicating.** The ticket is missing institutional knowledge. The human supplies what makes the failure reproducible.
3. **Mid-build.** Two reasonable solves, or the agent is heading the wrong way.
4. **At green.** The human watches the proof, then steps through it by hand.
5. **At review.** The human reads the findings and the PR. Agents are long-winded.

Each is a stop, not a prompt-and-proceed. The skill waits.

---

## Error handling

| Situation | Behavior |
|---|---|
| Red gate returns PASS | Stop. Present the three readings: not reproducible, wrong test case, not a bug. Human decides. |
| Any gate returns BLOCKED | Never counted as FAIL. Report what was missing, fix the Setup section, rerun. Three BLOCKED in a row on the same case stops the chain and asks the human. |
| Green gate returns FAIL | Return to `tdd-implement` with the verdict. After three failed green attempts, stop and ask the human. |
| Ticket source unreachable | Fall back through the adapter chain, then ask the human to paste the ticket. |
| No `docs/test-cases/` in the target repo | Create it and say so. |
| Test case edited between red and green | Detected by hashing the file at red. If the hash differs at green, warn loudly: the proof is void. |
| Full test suite fails for reasons unrelated to the ticket | Report as pre-existing, do not fix silently, ask whether to proceed. |

---

## Ticket sources

An adapter is one markdown file in `research-ticket/ticket-sources/`. The skill picks one by matching the reference shape, then follows that file's instructions.

| File | Reference shape | How |
|---|---|---|
| `github-issue.md` | `#123`, `owner/repo#123`, a github.com issue URL | `gh issue view` for body, comments, labels, linked PRs |
| `markdown-file.md` | a path ending `.md` | read the file |
| `plain-text.md` | anything else | treat the argument as the ticket body; ask for missing pieces |
| `aitickets.md` | reserved | stub for a private ticketing system. Records the interface each adapter must provide and is marked NOT IMPLEMENTED. |

Each adapter must produce the same four things: id, title, body, and any attached discussion. Adding a source means adding one file, no skill edits.

---

## Install and packaging

The repo is shaped as a Claude Code plugin **and** used as a symlink source. Both work off the same files.

```
cjm-skills-marketplace/
  .claude-plugin/
    marketplace.json
    plugin.json
  skills/
    research-ticket/SKILL.md
    research-ticket/ticket-sources/*.md
    blind-e2e/SKILL.md
    red-green-e2e/SKILL.md
    red-green-e2e/test-case-format.md
    green-green-e2e/SKILL.md
    tdd-implement/SKILL.md
    self-review/SKILL.md
    self-review/review-checklist.md
    implement/SKILL.md
  docs/
    research/
    superpowers/specs/
  scripts/
    link-skills.sh
  README.md
```

**On this machine:** `scripts/link-skills.sh` creates one symlink per skill, `~/.claude/skills/<name>` -> `<repo>/skills/<name>`. Edit the repo, the skill changes at once. No reinstall.

Each skill is linked **the moment it is written**, not at the end. After each link the script verifies the link resolves and the `SKILL.md` is readable.

Symlinked skills have open bugs against listing and validation (see the research notes). If listing breaks, the fallback is a copy-sync mode in the same script, chosen with a flag.

**Anywhere else:** `claude plugin marketplace add <repo>` then `claude plugin install agent-sdlc@cjm-skills-marketplace`. Skills then answer to `/agent-sdlc:...`.

---

## Testing the skills

Per `superpowers:writing-skills`, a skill is tested by pressure scenarios against subagents: watch an agent fail the task without the skill, add the skill, watch it comply.

Plan per skill:
1. Write the scenario and the pass condition before writing the skill.
2. Run the baseline without the skill. Record the failure.
3. Write the skill.
4. Rerun. It must comply.
5. Try to break it — the loopholes an agent would reach for.

`blind-e2e` gets one extra test that matters more than the rest: give the fork a test case for a bug that is **already fixed** and confirm it reports PASS, then a case for a bug that is **still open** and confirm it reports FAIL. A blind runner that cannot tell those apart is worthless.

**This needs your go-ahead.** Pressure testing spawns subagents, and the session rule is that I do not spawn them unless you ask.

---

## Verify at build time

Four mechanisms this design leans on that I have **not** confirmed on this machine. Each is checked with a throwaway skill before the skill that depends on it gets written. If one fails, the listed fallback is taken and this spec is updated.

**All four were probed on 2026-09-14.** Full write-up: [docs/research/2026-09-14-mechanism-probes.md](../../research/2026-09-14-mechanism-probes.md).

| Mechanism | Result |
|---|---|
| A symlinked `~/.claude/skills/<name>` lists and runs correctly | CONFIRMED |
| `context: fork` with `background: false` returns the fork's result to the caller in the same turn | CONFIRMED |
| `$1` interpolates inside a `` !`command` `` injection | **FALLBACK TAKEN** — `$1` resolves to empty. Use `$ARGUMENTS` or a named argument; both confirmed working |
| `disallowed-tools` actually removes those tools inside a forked skill | CONFIRMED — denied at invocation, though the tool stays visible in the fork's list |

One further observation: a skill created mid-session is not invocable at once. A rescan picks it up shortly after. That is a lag, not a restart requirement.

## Out of scope

- **Usage telemetry.** In-skill measurement, so a team can report adoption. Not needed for one machine. The skills leave a clean artifact trail (`docs/research/`, `docs/test-cases/`, `.sdlc/`), which is enough to add counting later without redesign.
- **Steps 08 to 11.** Code review by another human, QA, regression suites, release. Steps 08 and 09 are the open bottlenecks. Nothing here claims to solve them.
- **Epic-level skills.** An epic-level pipeline that calls this one is a second, larger project. Not built here.
- **XRay or any test-management integration.** Test cases land as markdown in the repo. Exporting them is a later, separate piece.
