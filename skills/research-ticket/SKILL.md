---
name: research-ticket
description: Turns a ticket reference into a research brief backed by code, git history and prior tickets, and surfaces the questions only a human can answer. Use at the start of work on a bug report, a support ticket, or a GitHub issue, before writing any test or any code.
arguments: ticket_ref
argument-hint: [ticket-ref]
---

# Research a ticket

Reference: `$ticket_ref`

The output is a brief the rest of the chain trusts. Everything downstream reads it
instead of re-reading the ticket, so what you leave out stays out.

## 1. Pick a ticket source

| The reference looks like | Use |
|---|---|
| `#123`, `owner/repo#123`, a github.com issue URL | [github-issue.md](ticket-sources/github-issue.md) |
| a path ending `.md` | [markdown-file.md](ticket-sources/markdown-file.md) |
| anything else | [plain-text.md](ticket-sources/plain-text.md) |
| reserved, not built yet | [aitickets.md](ticket-sources/aitickets.md) |

Each returns the same four things: id, title, body, discussion.

## 2. Read the repository

- The code paths the ticket names, and the ones it implies.
- `CONTEXT.md` and any ADRs, if the repo has them. Match their vocabulary in the brief —
  a rename between the ticket and the code is itself worth reporting.
- `git log` and `git blame` around the suspect area.

For a bug, find the change that introduced the behavior:

```bash
git log -S '<a string from the suspect code>' --oneline -- <path>
git log --oneline -20 -- <path>
```

Name the commit if you find one. "Broken since `a1b2c3d`" is the strongest backing a
brief can carry.

## 3. Look for prior art

Earlier tickets and earlier fixes touching the same area. A bug that was fixed once and
came back is a different problem from a bug reported for the first time, and it needs a
different fix.

```bash
git log --oneline --grep '<keyword>' -20
gh issue list --search '<keyword>' --state all --limit 20
```

## 4. Delegate external facts

For anything outside this repository — a library's real behavior, an API contract, a
specification — call the Skill tool with `mattpocock-skills:research`. It reads primary
sources in the background while you keep working.

Do not guess at third-party behavior. A wrong assumption about a dependency survives
every gate in this chain, because every gate tests our code against our assumption.

## 5. Backing is required

The brief must name **why** the expected behavior is correct. One of four:

1. A specification or documentation line that says so.
2. A version where it worked.
3. The commit that broke it.
4. Evidence the current behavior harms the person who reported it.

If none of the four exists, say so plainly and recommend **"this may not be a bug"**.

Software working as designed is not a bug, however clean the fix would be. This is the
check that stops the chain spending a day proving and fixing intended behavior. It is
cheapest here and most expensive at review.

## 6. Write the brief

To `docs/research/<ticket-id>.md`. First line, exactly:

```
ticket-id: <id>
```

Every later skill reads the id from that line rather than deriving it again.

Then these headings, in this order, none omitted:

```markdown
## Ticket
## Claimed behavior
## Expected behavior and its backing
## Suspect code paths
## History
## Prior art
## Open questions
## Recommendation
```

Write an empty section as "none found" rather than dropping it. A missing heading reads
as an oversight; "none found" is a finding.

## 7. Stop and ask

Put the open questions to the human and wait.

This is the first of the chain's five human gates, and it catches the two most expensive
failures: the behavior was intended, or the ticket describes a different bug from the
one actually in the code.

Good questions here are specific and answerable — "which account was signed in when this
happened?", not "can you give more detail?".

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.

A sentence that can be read two ways costs a round here. Call the `simple-english` skill
if it is installed. Short form: [WRITING-STANDARD.md](https://github.com/cjaymartin/skillz/blob/main/WRITING-STANDARD.md)
