---
name: self-review
description: Reviews your own change before a human sees it, across legitimacy, correctness, error handling, tests, security and style, using parallel reviewers with clean context. Use when a fix is complete and verified, before opening a pull request.
arguments: ticket_id
argument-hint: [ticket-id]
---

# Review your own work

Ticket: `$ticket_id`

This is the step that gets skipped under deadline. A skill makes it cheap enough to
keep.

## 1. Delegate the two axes that already exist

Call the Skill tool with `mattpocock-skills:code-review`. It runs a Standards pass and a
Spec pass in parallel and carries a code-smell baseline.

Give it the fixed point for the diff, and give it `docs/research/<ticket-id>.md` as the
spec source. That brief is what the change was supposed to do.

## 2. Add the legitimacy axis

Nothing else covers this one, and the whole chain hangs on it.

Read `docs/research/<ticket-id>.md` and check the backing still holds:

- Which of the four applies — a specification line, a version where it worked, the
  commit that broke it, or evidence the old behavior harmed the reporter?
- If none applies, say so at the top of the report. That finding outranks everything
  else, because a correct fix to intended behavior is still an unasked-for change.
- Did the diff fix the reported problem, or a different one found along the way?

Full questions: [review-checklist.md](review-checklist.md).

## 3. Run the remaining axes as parallel reviewers

One reviewer per axis, each with clean context, each given **only** its own section of
[review-checklist.md](review-checklist.md) plus the diff:

| Reviewer | Section |
|---|---|
| Correctness | Correctness and edge cases |
| Error handling | Error handling |
| Tests | Tests |
| Security | Security and performance |
| Style | Style and accuracy |

Separate context per reviewer is the point. A reviewer that has read the other axes'
findings starts agreeing with them instead of looking.

Paste each section into its reviewer's prompt. They cannot read this repository.

## 4. Do not rerank across axes

Report per axis. Never merge the findings into one ordered list, and never pick a single
worst finding overall.

One axis passing must not mask another failing. A change can follow every standard and
implement the wrong thing. A change can do exactly what the ticket asked and break every
convention in the repository. Merging the two hides whichever one you rank lower.

## 5. Output

Group findings by axis. Within an axis, worst first. Each finding carries the file and
line, and a concrete failure: the input, and what goes wrong with it.

End with one line per axis: the count, and the worst finding in that axis.

Drop anything the tooling already enforces. A linter finding is not a review finding,
and padding the report with them buries the real ones.

## 6. Stop and hand it to the human

This is the fifth and last human gate.

They are reading for accuracy and clarity, and agents are long-winded. Keep the report
to findings. No summary of what the change does — they can read the diff.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.

A sentence that can be read two ways costs a round here. Call the `simple-english` skill
if it is installed. Short form: [WRITING-STANDARD.md](https://github.com/cjaymartin/cjm-skills-marketplace/blob/main/WRITING-STANDARD.md)
