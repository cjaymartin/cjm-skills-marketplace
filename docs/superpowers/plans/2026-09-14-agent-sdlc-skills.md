# Agent-Driven SDLC Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build seven Claude Code skills that cover steps 02-07 of a ticket's life, chained by one `/implement` command, installed globally on this machine.

**Architecture:** Markdown-only. Each skill is a directory holding a `SKILL.md` plus reference files one level deep. `blind-e2e` is a forked skill with file-reading tools removed, which is what makes the end-to-end verdict trustworthy. Every other skill either calls `blind-e2e` or feeds it. The repo is shaped as a Claude Code plugin and is also the symlink source for `~/.claude/skills/`.

**Tech Stack:** Markdown, YAML frontmatter, bash, `gh` CLI, `claude plugin` CLI, Playwright MCP (already installed).

**Spec:** [docs/superpowers/specs/2026-09-14-agent-sdlc-skills-design.md](../specs/2026-09-14-agent-sdlc-skills-design.md)

## Global Constraints

- Every skill's `name` frontmatter value **must equal its directory name**. The slash command comes from the directory for personal skills and from `name` for plugin skills; keeping them identical makes one repo serve both.
- `name`: max 64 characters, lowercase letters, numbers, hyphens only. Must not contain the words `anthropic` or `claude`.
- `description`: non-empty, max 1024 characters, **third person**, states what the skill does **and** when to use it.
- Each `SKILL.md` body stays **under 500 lines**.
- Reference files link **one level deep from SKILL.md only**. No reference file links to another reference file.
- Any reference file over 100 lines opens with a table of contents.
- No product names, no employer names, no Jira, no `tsii`. These skills are generic.
- Blind verdicts are **PASS, FAIL, or BLOCKED**. Three values, never two. BLOCKED is never treated as FAIL.
- Each skill is symlinked into `~/.claude/skills/` the moment it is written, not at the end.
- Commit after every task. Push at the end of every task.

---

### Task 1: Probe the four unconfirmed mechanisms

The spec's "Verify at build time" section lists four behaviors the design leans on that have not been confirmed on this machine. Confirm them before building anything that depends on them.

**Files:**
- Create: `docs/research/2026-09-14-mechanism-probes.md`
- Create then delete: `~/.claude/skills/probe-fork/SKILL.md`
- Modify: `docs/superpowers/specs/2026-09-14-agent-sdlc-skills-design.md` (only if a probe fails)

**Interfaces:**
- Consumes: nothing.
- Produces: a confirmed or corrected mechanism table that Tasks 2, 3, and 4 depend on. If a probe fails, the fallback named in the spec becomes the design for the rest of the plan.

- [ ] **Step 1: Probe symlink listing**

```bash
mkdir -p /tmp/probe-src/probe-link
cat > /tmp/probe-src/probe-link/SKILL.md <<'EOF'
---
name: probe-link
description: Probe skill that confirms a symlinked personal skill is discovered by Claude Code. Use only when verifying skill installation mechanics.
---
Reply with exactly: PROBE-LINK-OK
EOF
ln -sfn /tmp/probe-src/probe-link ~/.claude/skills/probe-link
ls -l ~/.claude/skills/probe-link
cat ~/.claude/skills/probe-link/SKILL.md
```

Expected: the link resolves and `SKILL.md` prints. Record whether the skill also appears in the skill listing for a fresh session.

- [ ] **Step 2: Probe `context: fork` with `background: false`**

```bash
mkdir -p ~/.claude/skills/probe-fork
cat > ~/.claude/skills/probe-fork/SKILL.md <<'EOF'
---
name: probe-fork
description: Probe skill that confirms a forked skill returns its result to the caller in the same turn. Use only when verifying skill fork mechanics.
context: fork
agent: general-purpose
background: false
user-invocable: true
---
Return exactly this text and nothing else: PROBE-FORK-OK
EOF
cat ~/.claude/skills/probe-fork/SKILL.md
```

Then invoke `/probe-fork` and record whether `PROBE-FORK-OK` comes back inside the same turn.

Expected: the caller receives `PROBE-FORK-OK` without a separate task notification.

- [ ] **Step 3: Probe argument interpolation inside a `!` command injection**

```bash
echo "PROBE-ARG-CONTENT" > /tmp/probe-arg.txt
mkdir -p ~/.claude/skills/probe-arg
cat > ~/.claude/skills/probe-arg/SKILL.md <<'SKILLEOF'
---
name: probe-arg
description: Probe skill that confirms a positional argument interpolates inside a shell command injection. Use only when verifying skill argument mechanics.
argument-hint: [file-path]
---
Injected file content follows.

!`cat "$1"`

Report whether the line above reads PROBE-ARG-CONTENT or is empty.
SKILLEOF
cat ~/.claude/skills/probe-arg/SKILL.md
```

Then invoke `/probe-arg /tmp/probe-arg.txt` and record the result.

Expected: `PROBE-ARG-CONTENT` appears. If it is empty, the fallback is that callers pass the test case content inline.

- [ ] **Step 4: Probe `disallowed-tools` inside a fork**

```bash
mkdir -p ~/.claude/skills/probe-blind
cat > ~/.claude/skills/probe-blind/SKILL.md <<'EOF'
---
name: probe-blind
description: Probe skill that confirms disallowed-tools removes file-reading tools inside a forked context. Use only when verifying skill tool-restriction mechanics.
context: fork
agent: general-purpose
background: false
user-invocable: true
disallowed-tools: Read, Grep, Glob, Edit, Write, NotebookEdit
---
Try to read the file /tmp/probe-arg.txt using the Read tool.

Report exactly one of:
- TOOLS-BLOCKED if the Read tool is not available to you
- TOOLS-AVAILABLE if you were able to use it
EOF
cat ~/.claude/skills/probe-blind/SKILL.md
```

Then invoke `/probe-blind` and record the result.

Expected: `TOOLS-BLOCKED`. If `TOOLS-AVAILABLE`, blindness is instruction-only and every affected SKILL.md must say so plainly instead of claiming enforcement.

- [ ] **Step 5: Write the probe results**

Create `docs/research/2026-09-14-mechanism-probes.md` with one section per probe: what was run, what came back verbatim, and the decision taken. End with a table matching the spec's "Verify at build time" table, each row marked CONFIRMED or FALLBACK TAKEN.

- [ ] **Step 6: Update the spec if any probe failed**

For each FALLBACK TAKEN row, edit the affected section of `docs/superpowers/specs/2026-09-14-agent-sdlc-skills-design.md` so the spec describes what will actually be built. Leave the "Verify at build time" table in place with results filled in.

- [ ] **Step 7: Remove the probe skills**

```bash
rm -rf ~/.claude/skills/probe-fork ~/.claude/skills/probe-arg ~/.claude/skills/probe-blind
rm -f ~/.claude/skills/probe-link
rm -rf /tmp/probe-src /tmp/probe-arg.txt
ls ~/.claude/skills/
```

Expected: no `probe-*` entries remain.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Probe skill fork, symlink, argument and tool-restriction mechanics"
git push
```

---

### Task 2: Plugin manifests and the link script

Everything after this task gets linked by this script, so it comes second.

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `.claude-plugin/plugin.json`
- Create: `scripts/link-skills.sh`

**Interfaces:**
- Consumes: Task 1's symlink probe result.
- Produces: `scripts/link-skills.sh` with two modes — default symlink, and `--copy` fallback. Every later task ends by running `scripts/link-skills.sh <skill-name>` and confirming the skill resolves.

- [ ] **Step 1: Write the marketplace manifest**

```bash
cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "skillz",
  "owner": {
    "name": "C. Jay Martin",
    "email": "cjay.martin@gmail.com"
  },
  "plugins": [
    {
      "name": "agent-sdlc",
      "source": "./",
      "description": "An agent-driven SDLC: research a ticket, prove the failure blind, build it test-first, prove the fix blind, review your own work."
    }
  ]
}
EOF
```

- [ ] **Step 2: Write the plugin manifest**

```bash
cat > .claude-plugin/plugin.json <<'EOF'
{
  "name": "agent-sdlc",
  "description": "An agent-driven SDLC: research a ticket, prove the failure blind, build it test-first, prove the fix blind, review your own work.",
  "version": "0.1.0",
  "author": {
    "name": "C. Jay Martin"
  }
}
EOF
```

- [ ] **Step 3: Write the link script**

Create `scripts/link-skills.sh`. Required behavior, all of it:

- Resolves the repo root from the script's own location, so it works from any directory.
- With no argument, links every directory under `skills/`. With one argument, links only that skill.
- Default mode symlinks `~/.claude/skills/<name>` to `<repo>/skills/<name>`.
- `--copy` mode copies instead, for the case where symlinked skills fail to list.
- Refuses to overwrite a real directory that is not a symlink this script made, and says which path it refused and why.
- After each link, verifies the target `SKILL.md` is readable through the link and that its `name:` frontmatter value equals the directory name. Fails loudly on mismatch, because that mismatch silently breaks the plugin install path.
- Prints one line per skill: name, mode, and OK or the reason it failed.
- `set -euo pipefail` at the top.

- [ ] **Step 4: Make it executable and run it**

```bash
chmod +x scripts/link-skills.sh
scripts/link-skills.sh
```

Expected: it reports that `skills/` holds no skills yet and exits 0. An empty run must not be an error.

- [ ] **Step 5: Validate the plugin**

```bash
claude plugin validate .
```

Expected: valid. If the CLI reports a schema problem, fix the manifest to match what it asks for and rerun until clean.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add plugin manifests and the skill link script"
git push
```

---

### Task 3: The `blind-e2e` skill

The leaf every other e2e skill calls. Build it first so the callers have something real to call.

**Files:**
- Create: `skills/blind-e2e/SKILL.md`

**Interfaces:**
- Consumes: Task 1's fork, argument-injection, and tool-restriction results. Task 2's link script.
- Produces: the invocation `/blind-e2e <test-case-path>` and the verdict block format below. Tasks 4 and 5 call it and parse this block. The block's field names are fixed and must not drift.

Verdict block, exactly:

```
VERDICT: PASS | FAIL | BLOCKED
TEST CASE: <path>
STEPS OBSERVED:
  1. <what was done> -> <what was seen>
EVIDENCE: <screenshot paths, command output, URLs>
REASON: <one sentence; required for FAIL and BLOCKED, omitted for PASS>
```

- [ ] **Step 1: Write the frontmatter**

```yaml
---
name: blind-e2e
description: Runs one plain-English test case in an isolated agent that cannot see the ticket, the diff, or the source code, and reports PASS, FAIL, or BLOCKED with evidence. Use when another skill needs an unbiased end-to-end verdict on whether a behavior works. Not for direct use.
context: fork
agent: general-purpose
background: false
user-invocable: false
disallowed-tools: Read, Grep, Glob, Edit, Write, NotebookEdit
argument-hint: [test-case-path]
---
```

If Task 1 Step 4 returned `TOOLS-AVAILABLE`, keep the `disallowed-tools` line and add a body section headed "Blindness is on your honour here" stating that the restriction did not take effect and the agent must not read source files.

If Task 1 Step 3 showed `$1` does not interpolate inside `` !`...` ``, drop the injection line and instead require the caller to paste the test case content into the invocation.

- [ ] **Step 2: Write the body**

Required sections, in this order:

1. **What you know** — the test case is the whole world. State plainly that the agent has not been told what the right answer is, and that this is deliberate.
2. **The test case** — the injected content, via `` !`cat "$1"` ``.
3. **How to run it** — start the app using only commands the test case's Setup section names. Follow the Steps exactly, in order. Observe what the Expected section describes.
4. **The three verdicts** — PASS when the Expected outcome was observed. FAIL when it was not. BLOCKED when the case could not be run at all: the app would not start, a credential was missing, a step was ambiguous. State that guessing between FAIL and BLOCKED is the single worst thing this skill can do.
5. **Rules** — never read source files. Never infer what the answer is supposed to be. Never fix anything. Never edit the test case. Report only what was observed.
6. **Output** — the verdict block, verbatim from the Interfaces section above.

- [ ] **Step 3: Link it and verify**

```bash
scripts/link-skills.sh blind-e2e
ls -l ~/.claude/skills/blind-e2e
head -12 ~/.claude/skills/blind-e2e/SKILL.md
```

Expected: link resolves, frontmatter prints, `name: blind-e2e` matches the directory.

- [ ] **Step 4: Test it against a known-passing case**

```bash
mkdir -p /tmp/blind-trial/docs/test-cases
cat > /tmp/blind-trial/docs/test-cases/echo-works.md <<'EOF'
# Echo prints its argument

## Setup
No application to start. Use a shell.

## Steps
1. Run the command: echo hello-blind-trial

## Expected
The output is the single line: hello-blind-trial
EOF
```

Invoke `/blind-e2e /tmp/blind-trial/docs/test-cases/echo-works.md`.

Expected: `VERDICT: PASS`, with the observed output as evidence.

- [ ] **Step 5: Test it against a known-failing case**

```bash
cat > /tmp/blind-trial/docs/test-cases/echo-fails.md <<'EOF'
# Echo prints a different word

## Setup
No application to start. Use a shell.

## Steps
1. Run the command: echo hello-blind-trial

## Expected
The output is the single line: goodbye-blind-trial
EOF
```

Invoke `/blind-e2e /tmp/blind-trial/docs/test-cases/echo-fails.md`.

Expected: `VERDICT: FAIL`, with a REASON naming the mismatch.

**This pair is the gate for the whole repo.** A blind runner that cannot tell these two apart is worthless. If both return the same verdict, fix the skill and rerun both before moving on.

- [ ] **Step 6: Test it against an unrunnable case**

```bash
cat > /tmp/blind-trial/docs/test-cases/echo-blocked.md <<'EOF'
# Open the reporting dashboard

## Steps
1. Open the dashboard.
2. Check the number.

## Expected
The number is correct.
EOF
```

Invoke `/blind-e2e /tmp/blind-trial/docs/test-cases/echo-blocked.md`.

Expected: `VERDICT: BLOCKED`, with a REASON naming the missing Setup section and the ambiguous steps. Not FAIL.

- [ ] **Step 7: Clean up and commit**

```bash
rm -rf /tmp/blind-trial
git add -A
git commit -m "Add blind-e2e: an isolated, source-blind end-to-end test runner"
git push
```

---

### Task 4: The `red-green-e2e` skill and the test case format

**Files:**
- Create: `skills/red-green-e2e/SKILL.md`
- Create: `skills/red-green-e2e/test-case-format.md`

**Interfaces:**
- Consumes: `/blind-e2e <test-case-path>` and its verdict block from Task 3.
- Produces: `/red-green-e2e red <ticket-id>` and `/red-green-e2e green <ticket-id>`. Writes `docs/test-cases/<ticket-id>-<slug>.md` in the target repo and `.sdlc/runs/<ticket-id>/<mode>-<timestamp>.md`. Task 9 calls both modes.

- [ ] **Step 1: Write the test case format reference**

Create `skills/red-green-e2e/test-case-format.md`. It opens with a table of contents if it passes 100 lines. It contains:

- The three required sections `## Setup`, `## Steps`, `## Expected`, with the template from the spec.
- The rules: plain English only, no selectors, no function names, no source paths. Expected describes what a person sees, never what the code does. Never mention the bug, the ticket, or the fix.
- Why Setup completeness matters: an incomplete Setup produces BLOCKED, and BLOCKED costs a whole round.
- Two worked examples, one web and one command-line, each complete enough to hand to a stranger.
- Three bad examples with the specific reason each one is bad: one that names a CSS selector, one that says "the bug should not happen", one whose Setup omits how to log in.

- [ ] **Step 2: Write the skill frontmatter**

```yaml
---
name: red-green-e2e
description: Proves a reported bug is real before the fix and proves it is gone after, by running the same plain-English test case through a source-blind agent twice. Use when replicating a failure, verifying a fix, or when a ticket needs end-to-end proof rather than a unit test.
argument-hint: [red|green] [ticket-id]
---
```

- [ ] **Step 3: Write the skill body**

Required sections:

1. **Two modes** — the two invocations, verbatim from the Interfaces block.
2. **Red mode**, as five numbered steps: find or write the case at `docs/test-cases/<ticket-id>-<slug>.md` following [test-case-format.md](test-case-format.md); record the file's SHA-256 into `.sdlc/<ticket-id>/state.md`; call `/blind-e2e` on it; gate on FAIL; persist the verdict block to `.sdlc/runs/<ticket-id>/red-<timestamp>.md`.
3. **When red returns PASS** — stop. Put three readings to the human and wait: the bug is not reproducible, the test case is wrong, or it is not a bug. Do not pick one.
4. **When any run returns BLOCKED** — fix the Setup section and rerun. Never count it as a pass or a fail. Three BLOCKED on the same case stops the chain and asks the human.
5. **Green mode**, as five numbered steps: read the same file; re-hash it and compare against the hash recorded at red; call `/blind-e2e`; gate on PASS; persist to `.sdlc/runs/<ticket-id>/green-<timestamp>.md`.
6. **Never edit the case between red and green** — with the reason: the two runs are only comparable if the question did not change. If the hash differs, say loudly that the proof is void and stop.
7. **When green returns FAIL** — hand the verdict back to `tdd-implement`. After three failed green attempts, stop and ask the human.

- [ ] **Step 4: Link and verify**

```bash
scripts/link-skills.sh red-green-e2e
head -8 ~/.claude/skills/red-green-e2e/SKILL.md
wc -l skills/red-green-e2e/SKILL.md skills/red-green-e2e/test-case-format.md
```

Expected: link resolves, `name: red-green-e2e`, SKILL.md under 500 lines.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add red-green-e2e and the plain-English test case format"
git push
```

---

### Task 5: The `green-green-e2e` skill

**Files:**
- Create: `skills/green-green-e2e/SKILL.md`

**Interfaces:**
- Consumes: `/blind-e2e <test-case-path>` from Task 3; the format reference at `skills/red-green-e2e/test-case-format.md` from Task 4, referenced by path rather than copied.
- Produces: `/green-green-e2e before <ticket-id>` and `/green-green-e2e after <ticket-id>`.

- [ ] **Step 1: Write the frontmatter**

```yaml
---
name: green-green-e2e
description: Guards against regressions by running the same plain-English test cases through a source-blind agent before and after a change, requiring a pass both times. Use for refactors, rethemes, dependency bumps, or any change that must not alter existing behavior.
argument-hint: [before|after] [ticket-id]
---
```

- [ ] **Step 2: Write the body**

Required sections:

1. **What this is for** — behavior that already works and must keep working. Contrast it with `red-green-e2e` in one sentence so the reader picks the right one.
2. **Before mode** — pick or write cases for behavior that works today; hash each; run one `/blind-e2e` fork per case; gate every case on PASS.
3. **A FAIL in before mode is not a regression** — it means the behavior was already broken, so it is not a valid guard. Report it and stop. Do not proceed to after mode with a known-broken case.
4. **After mode** — same files, unedited, hashes re-checked; one fork per case; gate on PASS.
5. **One fork per case** — with the reason: a case that blocks or fails must not pollute another case's context.
6. **Reporting a regression** — name the case, name the step, and show the before and after evidence side by side.

- [ ] **Step 3: Link and verify**

```bash
scripts/link-skills.sh green-green-e2e
head -8 ~/.claude/skills/green-green-e2e/SKILL.md
```

Expected: link resolves, `name: green-green-e2e`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Add green-green-e2e regression guard"
git push
```

---

### Task 6: The `research-ticket` skill and its ticket sources

**Files:**
- Create: `skills/research-ticket/SKILL.md`
- Create: `skills/research-ticket/ticket-sources/github-issue.md`
- Create: `skills/research-ticket/ticket-sources/markdown-file.md`
- Create: `skills/research-ticket/ticket-sources/plain-text.md`
- Create: `skills/research-ticket/ticket-sources/aitickets.md`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `/research-ticket <ticket-ref>`, and the brief at `docs/research/<ticket-id>.md`. Tasks 7, 8, and 9 read that brief. Its section headings are fixed: `## Ticket`, `## Claimed behavior`, `## Expected behavior and its backing`, `## Suspect code paths`, `## History`, `## Prior art`, `## Open questions`, `## Recommendation`. The brief's first line is `ticket-id: <id>`, which every later skill reads rather than re-deriving.

- [ ] **Step 1: Write the four adapters**

Each adapter is a short file that produces the same four things: **id, title, body, discussion**. State that contract at the top of each file.

`github-issue.md` — matches `#123`, `owner/repo#123`, or a `github.com` issue URL. Uses:

```bash
gh issue view <number> --json number,title,body,comments,labels,state,url
```

Sets id to `gh-<number>`. Says to also check linked pull requests with `gh issue view <number> --json closedByPullRequestsReferences` and to report if the issue is already closed.

`markdown-file.md` — matches a path ending `.md`. Reads the file. Sets id to the file's basename without the extension.

`plain-text.md` — the fallback. Treats the whole argument as the ticket body. Sets id to a slug the human confirms. Says explicitly to ask the human for a title and an id rather than inventing one.

`aitickets.md` — a stub. Marked **NOT IMPLEMENTED** in its first line. Records the id, title, body, discussion contract that any adapter must satisfy, and names `~/WebstormProjects/aitickets` as the intended source. Says to fall back to `plain-text.md` until it is built.

- [ ] **Step 2: Write the skill frontmatter**

```yaml
---
name: research-ticket
description: Turns a ticket reference into a research brief backed by code, git history and prior tickets, and surfaces the questions only a human can answer. Use at the start of work on a bug report, a support ticket, or a GitHub issue, before writing any test or code.
argument-hint: [ticket-ref]
---
```

- [ ] **Step 3: Write the body**

Required sections:

1. **Pick a ticket source** — a table mapping reference shape to adapter file, each linked one level deep: [github-issue.md](ticket-sources/github-issue.md), [markdown-file.md](ticket-sources/markdown-file.md), [plain-text.md](ticket-sources/plain-text.md), [aitickets.md](ticket-sources/aitickets.md).
2. **Read the repo** — the code paths named or implied, `CONTEXT.md` and any ADRs, `git log` and `git blame` around the suspect area, and the commit that introduced the behavior when it is a bug.
3. **Prior art** — search for earlier tickets and earlier fixes touching the same area.
4. **External facts** — delegate to `mattpocock-skills:research` for anything outside this repo, such as a library's real behavior or an API contract. Do not guess at third-party behavior.
5. **Backing is required** — the brief must name why the expected behavior is correct: a spec line, a version where it worked, the commit that broke it, or evidence of client impact. If none of the four exists, say so and recommend "this may not be a bug". Software working as designed is not a bug, however clean the fix would be.
6. **Write the brief** — to `docs/research/<ticket-id>.md`, with the fixed headings from the Interfaces block and `ticket-id: <id>` as the first line.
7. **Stop and ask** — put the open questions to the human and wait. This is the first of the chain's five human gates.

- [ ] **Step 4: Link and verify**

```bash
scripts/link-skills.sh research-ticket
head -8 ~/.claude/skills/research-ticket/SKILL.md
ls ~/.claude/skills/research-ticket/ticket-sources/
```

Expected: link resolves, `name: research-ticket`, four adapter files visible through the link.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add research-ticket and four swappable ticket sources"
git push
```

---

### Task 7: The `tdd-implement` skill

**Files:**
- Create: `skills/tdd-implement/SKILL.md`

**Interfaces:**
- Consumes: `docs/research/<ticket-id>.md` from Task 6, and its fixed headings.
- Produces: `/tdd-implement <ticket-id>`. Task 9 calls it, and hands it a failing green verdict when `red-green-e2e green` returns FAIL.

- [ ] **Step 1: Write the frontmatter**

```yaml
---
name: tdd-implement
description: Builds a ticket's fix test-first, one vertical slice at a time, at seams the human agreed to in advance. Use after a failure has been replicated and before any end-to-end verification of the fix.
argument-hint: [ticket-id]
---
```

- [ ] **Step 2: Write the body**

Required sections. This skill adds ticket wiring and stop points only; it must not restate the TDD rules that the two skills below already carry.

1. **Read the brief first** — `docs/research/<ticket-id>.md`.
2. **Load the two skills that own the method** — invoke `superpowers:test-driven-development` for the red-green loop discipline, and `mattpocock-skills:tdd` for what a good test is, where seams go, and the anti-patterns. Say plainly that this skill deliberately does not repeat them.
3. **Agree the seams before writing a test** — propose the public boundaries under test, then stop and wait. No test is written at a seam the human has not agreed to. This is human gate two.
4. **One vertical slice at a time** — one failing unit test, then the smallest code that passes it, then the next slice. Never all tests then all code, and name why: bulk tests verify imagined behavior and lock in structure before the implementation is understood.
5. **Run checks every slice** — typecheck and the touched test files each slice; the full suite once at the end.
6. **A pre-existing failure is not yours to fix silently** — report it, ask whether to proceed.
7. **Two reasonable designs means stop** — present both with the trade-off and wait. This is human gate three. Do not pick quietly.
8. **When called back after a failed green gate** — read the verdict block, treat the REASON as the next failing case, and resume the loop. Do not start over.

- [ ] **Step 3: Link and verify**

```bash
scripts/link-skills.sh tdd-implement
head -8 ~/.claude/skills/tdd-implement/SKILL.md
```

Expected: link resolves, `name: tdd-implement`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Add tdd-implement, wiring the ticket into the red-green loop"
git push
```

---

### Task 8: The `self-review` skill and its checklist

**Files:**
- Create: `skills/self-review/SKILL.md`
- Create: `skills/self-review/review-checklist.md`

**Interfaces:**
- Consumes: `docs/research/<ticket-id>.md` from Task 6, for the Legitimacy axis's backing evidence.
- Produces: `/self-review <ticket-id>`. Task 9 calls it last.

- [ ] **Step 1: Write the checklist reference**

Create `skills/self-review/review-checklist.md`, opening with a table of contents. One section per axis, each holding the concrete questions a reviewer asks:

- **Legitimacy** — Was this really a bug? Which of the four backings applies: a spec, a version where it worked, the commit that broke it, evidence of client impact? Is the code working as designed?
- **Correctness and edge cases** — empty, null, boundary, unusual inputs.
- **Error handling** — surfaced or swallowed? Silent failure paths, misleading messages, dead or redundant handlers.
- **Tests** — do they assert the behavior, or pass for the wrong reason? Were they red-greened? Flaky or brittle? Gaps on the headline behavior and on its failure path.
- **Security and performance** — new exposure, new slowdown.
- **Style and accuracy** — consistency with surrounding code, comments that match the code, documentation claims spot-checked.

- [ ] **Step 2: Write the frontmatter**

```yaml
---
name: self-review
description: Reviews your own change before a human sees it, across legitimacy, correctness, error handling, tests, security and style, using parallel reviewers with clean context. Use when a fix is complete and verified, before opening a pull request.
argument-hint: [ticket-id]
---
```

- [ ] **Step 3: Write the body**

Required sections:

1. **Delegate the two axes that already exist** — invoke `mattpocock-skills:code-review` for its Standards and Spec passes and its Fowler smell baseline. Pass it the research brief as the spec source.
2. **Add the Legitimacy axis** — the one nothing else covers, and the one the whole chain hangs on. Read `docs/research/<ticket-id>.md` and check the backing holds. Working as designed is not a bug.
3. **Run the remaining axes in parallel reviewers** — one reviewer per axis, each with clean context, each pointed at the checklist section it owns via [review-checklist.md](review-checklist.md).
4. **Do not rerank across axes** — report per axis, and say why: one axis passing must never mask another failing.
5. **Output** — findings grouped by axis, worst first within each axis, each with the file and line. End with one line per axis giving the count and the worst finding in that axis.
6. **Stop and hand it to the human** — this is human gate five. Note that agents are long-winded and the human is reading for accuracy and clarity.

- [ ] **Step 4: Link and verify**

```bash
scripts/link-skills.sh self-review
head -8 ~/.claude/skills/self-review/SKILL.md
```

Expected: link resolves, `name: self-review`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add self-review with the legitimacy axis"
git push
```

---

### Task 9: The `implement` orchestrator

**Files:**
- Create: `skills/implement/SKILL.md`

**Interfaces:**
- Consumes: `/research-ticket`, `/red-green-e2e red|green`, `/tdd-implement`, `/self-review` — all six invocations exactly as their tasks defined them.
- Produces: `/implement <ticket-ref>`, and the resumable state file `.sdlc/<ticket-id>/state.md`.

- [ ] **Step 1: Write the frontmatter**

```yaml
---
name: implement
description: Runs a ticket end to end through research, blind failure replication, test-first implementation, blind success verification and self-review, stopping at each point that needs a human decision. Use when asked to work a ticket, issue or bug report from start to pull request.
disable-model-invocation: true
argument-hint: [ticket-ref]
---
```

`disable-model-invocation: true` is required: this runs only when the user asks.

- [ ] **Step 2: Write the body**

Required sections:

1. **The sequence**, as a table of six rows: the skill invoked, and the gate that must clear before the next row runs. Copy the table from the spec's `implement` section.
2. **Resume before starting** — read `.sdlc/<ticket-id>/state.md` if it exists, report which step it stopped at and why, and continue from there. Never restart a finished step.
3. **The state file format** — a checklist, one line per step, each finished line carrying the artifact path it produced. Written after every step, not at the end.
4. **Gitignore** — add `.sdlc/` to the target repo's `.gitignore` if it is not already there, and say so.
5. **The five human gates** — listed with what the human is actually deciding at each, from the spec. State that each is a stop, not a prompt-and-proceed. The skill waits.
6. **The name clash** — one line noting that `mattpocock-skills:implement` still exists at `/mattpocock-skills:implement`.
7. **What this does not cover** — steps 08 to 11: another human's code review, QA, regression testing, release. Do not claim otherwise.

- [ ] **Step 3: Link and verify**

```bash
scripts/link-skills.sh implement
head -8 ~/.claude/skills/implement/SKILL.md
```

Expected: link resolves, `name: implement`.

- [ ] **Step 4: Verify all seven skills are linked**

```bash
scripts/link-skills.sh
ls -l ~/.claude/skills/ | grep -E "blind-e2e|red-green-e2e|green-green-e2e|research-ticket|tdd-implement|self-review|implement"
```

Expected: seven symlinks, each into this repo.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add the implement orchestrator"
git push
```

---

### Task 10: Whole-repo verification and the README

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-09-14-agent-sdlc-skills-design.md` (status line only)

**Interfaces:**
- Consumes: everything.
- Produces: a repo that validates as a plugin and installs by symlink.

- [ ] **Step 1: Check every skill against the global constraints**

```bash
for f in skills/*/SKILL.md; do
  d=$(basename "$(dirname "$f")")
  n=$(sed -n 's/^name: *//p' "$f" | head -1)
  l=$(wc -l < "$f")
  if [ "$d" = "$n" ]; then m=OK; else m="MISMATCH ($n)"; fi
  if [ "$l" -lt 500 ]; then s=OK; else s="TOO LONG"; fi
  printf '%-18s name:%-12s lines:%-5s %s\n' "$d" "$m" "$l" "$s"
done
```

Expected: every row reads `name:OK` and `lines:OK`. Fix any that do not before continuing.

- [ ] **Step 2: Check every description is third person and non-empty**

```bash
grep -h '^description:' skills/*/SKILL.md
```

Expected: seven lines. Read each one. None may start with "I " or "You ". Each must say what it does and when to use it. Each must be under 1024 characters.

- [ ] **Step 3: Check reference links are one level deep**

```bash
grep -rn '](.*\.md)' skills/*/*.md
```

Expected: every link appears in a `SKILL.md`, never in a reference file. A link inside a reference file is a violation and must be flattened.

- [ ] **Step 4: Validate the plugin**

```bash
claude plugin validate .
```

Expected: valid.

- [ ] **Step 5: Rewrite the README**

Replace the status line with what actually exists. Add a table of the seven skills, one line each, naming what it does and its invocation. Add a short "how the chain runs" section with the six-row sequence. Keep the prerequisites and both install paths.

- [ ] **Step 6: Update the spec status**

Change the spec's status wording from design-approved to built, and record the date.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "Verify all seven skills and document the finished chain"
git push
git log --oneline
```

---

## Not in this plan

**Pressure testing the skills with subagents.** The spec's testing section describes it and it is the right next step, but spawning subagents needs the user's explicit go-ahead under this session's rules. Task 3 Steps 4 to 6 are the exception: they test `blind-e2e` through its own fork, which the user's design already asked for, and they are the one test the repo cannot ship without.
