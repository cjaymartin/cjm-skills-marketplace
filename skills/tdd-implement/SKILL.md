---
name: tdd-implement
description: Builds a ticket's fix test-first, one vertical slice at a time, at seams the human agreed to in advance. Use after a failure has been replicated and before any end-to-end verification of the fix.
arguments: ticket_id
argument-hint: [ticket-id]
---

# Build the fix, test first

Ticket: `$ticket_id`

This skill carries the ticket wiring and the stop points. It deliberately does **not**
restate how to do test-driven development — two skills already own that, and a second
copy would drift from them.

## 1. Read the brief first

`docs/research/<ticket-id>.md`. You need **Expected behavior and its backing**,
**Suspect code paths**, and whatever the human answered under **Open questions**.

If the brief is missing, stop and run `research-ticket` first. Building from the raw
ticket skips the legitimacy check, and that check is the reason the chain starts where
it does.

## 2. Load the two skills that own the method

Call the Skill tool for both:

- `superpowers:test-driven-development` — the red-green loop discipline.
- `mattpocock-skills:tdd` — what a good test is, where seams go, the anti-patterns.

Follow them. Everything below is the ticket wiring around them.

## 3. Agree the seams before writing any test

A **seam** is the public boundary you observe behavior at, without reaching inside.

Propose the seams for this ticket, then **stop and wait**. No test is written at a seam
the human has not agreed to.

This is human gate two. It is where testing effort gets aimed at the critical path
instead of spread across every edge case, and it is cheap only before any test exists.

## 4. One vertical slice at a time

One failing unit test. Then the smallest code that passes it. Then the next slice.

**Never all tests then all code.** Bulk tests verify behavior you imagined rather than
behavior you found. They lock in a test structure before the implementation is
understood, and they go insensitive to the changes that matter.

Each test is a tracer bullet: it responds to what the last slice taught you.

## 5. Run checks every slice

- Typecheck, every slice.
- The test files you touched, every slice.
- The full suite once, at the end.

## 6. A pre-existing failure is not yours to fix silently

If the full suite fails for reasons unrelated to this ticket, report it as pre-existing
and ask whether to proceed. Do not fix it quietly — an unrelated fix inside this
ticket's diff makes the change hard to review and hard to revert.

## 7. Two reasonable designs means stop

When two approaches are both defensible, present both with the trade-off and wait. This
is human gate three.

Do not pick quietly. A silent choice here is the most expensive thing in the chain: it
survives every gate, because every gate tests the design you chose against itself.

Also stop when you notice you are on the third attempt at the same thing by a different
route. That is the same gate arriving late.

## 8. When called back after a failed green gate

`red-green-e2e green` returned FAIL and handed you the verdict block.

Read the REASON line. Treat it as the next failing case and resume the loop where you
left off. Do not start over, and do not rewrite tests that already pass.

If this is the third failed green attempt, stop and go to the human. Three failures
means the understanding is wrong, not the code.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.

A sentence that can be read two ways costs a round here. Call the `simple-english` skill
if it is installed. Short form: [WRITING-STANDARD.md](https://github.com/cjaymartin/skillz/blob/main/WRITING-STANDARD.md)
