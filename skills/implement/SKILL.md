---
name: implement
description: Runs a ticket end to end through research, blind failure replication, test-first implementation, blind success verification and self-review, stopping at each point that needs a human decision. Use when asked to work a ticket, issue or bug report from start to pull request.
disable-model-invocation: true
arguments: ticket_ref
argument-hint: [ticket-ref]
---

# Work a ticket end to end

Ticket: `$ticket_ref`

Covers the part of a ticket's life a developer owns alone: research it, prove it is
broken, build it test-first, prove it is fixed, review your own work.

The point is not automation. It is to compress the typing **between** decisions so one
person can hold several tickets at once. Every decision stays with the human.

## Resume before you start

Read `.sdlc/<ticket-id>/state.md` if it exists.

Report which step it stopped at and why, then continue from there. Never restart a step
that finished — the artifacts it produced are still on disk and still valid.

If there is no state file, this is a fresh start.

## The sequence

| # | Run | Gate before the next row |
|---|---|---|
| 1 | `research-ticket $ticket_ref` | Human answers the open questions and confirms this is the right bug |
| 2 | `red-green-e2e red <ticket-id>` | Blind verdict must be **FAIL** |
| 3 | `tdd-implement <ticket-id>` | Human agrees the seams; human picks when two designs are offered |
| 4 | `red-green-e2e green <ticket-id>` | Blind verdict must be **PASS** |
| 5 | Human steps through the proof by hand | Human confirms |
| 6 | `self-review <ticket-id>` | Human reads the findings |

Call each through the Skill tool. Take the `<ticket-id>` from the first line of
`docs/research/<ticket-id>.md`, which step 1 writes. Do not derive it again.

## The state file

`.sdlc/<ticket-id>/state.md`, written after **every** step, not at the end. A checklist,
one line per step, each finished line carrying the artifact it produced:

```markdown
# <ticket-id>

- [x] research — docs/research/<ticket-id>.md
- [x] red — .sdlc/runs/<ticket-id>/red-20260914-1731.md — FAIL
- [ ] implement — in progress, waiting on seam agreement
- [ ] green
- [ ] human walkthrough
- [ ] self-review
```

Writing it after every step is what makes running several tickets at once survivable.
Written at the end, it is a log. Written as you go, it is a resume point.

## Gitignore

Add `.sdlc/` to the target repository's `.gitignore` if it is not already there, and say
that you did. Run artifacts and progress are working files, not history.

`docs/research/` and `docs/test-cases/` **are** committed. The test cases outlive the
ticket.

## The five human gates

Each is a stop. You wait. Not a prompt followed by proceeding.

1. **After research.** The agent reports the behavior was intended, or found a different
   bug from the one reported. Continue or not?
2. **Before replicating.** The ticket is missing institutional knowledge. The human
   supplies what makes the failure reproducible.
3. **Mid-build.** Two reasonable solves, or the agent is heading the wrong way.
4. **At green.** The human watches the proof, then steps through it by hand. A blind
   agent saying PASS is evidence, not a substitute for looking.
5. **At review.** The human reads the findings and the pull request.

None of these is a missing feature. Each is a decision only a person can make. The
skills remove the typing between them.

## When a gate does not clear

- **Red returns PASS** — stop. `red-green-e2e` puts three readings to the human. Do not
  choose one for them.
- **Any run returns BLOCKED** — never a pass, never a fail. Repair the Setup section and
  rerun. Three BLOCKED on the same case stops the chain.
- **Green returns FAIL** — back to step 3 with the verdict. Three failed green attempts
  stops the chain.

## The name clash

`mattpocock-skills` also ships an `implement` skill. Theirs is still there as
`/mattpocock-skills:implement`. The bare `/implement` is this one.

## What this does not cover

Steps 08 to 11 of a ticket's life: another person's code review, QA, regression testing,
release. Nothing here claims to solve them, and `self-review` is not a substitute for a
second reader.
